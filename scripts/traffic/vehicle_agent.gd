class_name CivicVehicleAgent
extends Node3D
## Fixed-step lane follower with continuous centerline sampling.

signal route_completed
signal route_rejected(reason: String)

@export var profile: CivicVehicleProfile

## Presentation is a soft dependency: the driving script must still load
## if optional cue code is missing or its class_name cache is unavailable.
var feedback: Node3D
var feedback_script_path: String = "res://scripts/npc/agent_feedback.gd"
var feedback_enabled: bool = true

func _ready() -> void:
    if not feedback_enabled:
        return
    if not ResourceLoader.exists(feedback_script_path):
        push_warning("Optional agent feedback script missing; vehicle simulation continues")
        return
    var feedback_script: Script = load(feedback_script_path) as Script
    if feedback_script == null:
        push_warning("Optional agent feedback script could not load; vehicle simulation continues")
        return
    var instance: Variant = feedback_script.new()
    if not (instance is Node3D) or not instance.has_method("observe_vehicle"):
        if instance is Node:
            instance.free()
        push_warning("Optional agent feedback has an incompatible scene contract")
        return
    feedback = instance as Node3D
    feedback.name = "AgentFeedback"
    add_child(feedback)

var road_graph: CivicRoadGraph
var route: PackedInt32Array = PackedInt32Array()
var current_route_index: int = 0
var lane_distance_m: float = 0.0
var speed_mps: float = 0.0
var target_speed_mps: float = 0.0
var stop_requested: bool = false
var active: bool = false
@export_range(0.5, 10.0, 0.1) var minimum_gap_m: float = 2.0
@export_range(0.1, 3.0, 0.1) var reaction_seconds: float = 0.8
var lead_gap_m: float = INF
var lead_speed_mps: float = 0.0
## Disabled only for legacy isolated junction throughput simulations.
var physics_obstacle_checks_enabled: bool = true

func set_lead_observation(gap_m: float, speed: float) -> void:
    lead_gap_m = maxf(0.0, gap_m)
    lead_speed_mps = maxf(0.0, speed)

func clear_lead_observation() -> void:
    lead_gap_m = INF
    lead_speed_mps = 0.0


func configure(graph: CivicRoadGraph, lane_ids: PackedInt32Array, vehicle_profile: CivicVehicleProfile) -> bool:
    active = false
    speed_mps = 0.0
    route = PackedInt32Array()
    if graph == null or vehicle_profile == null or not vehicle_profile.is_valid() or lane_ids.is_empty():
        route_rejected.emit("invalid_configuration")
        return false
    if not graph.validate().is_empty():
        route_rejected.emit("invalid_graph")
        return false
    for index in range(lane_ids.size()):
        var lane := graph.get_lane(lane_ids[index])
        if lane == null or lane.is_wrong_way_connector or not lane.is_vehicle_allowed(vehicle_profile.vehicle_mask):
            route_rejected.emit("restricted_lane")
            return false
        if index > 0 and not graph.outgoing_legal_lanes(lane_ids[index - 1], vehicle_profile.vehicle_mask).has(lane_ids[index]):
            route_rejected.emit("disconnected_route")
            return false
    road_graph = graph
    profile = vehicle_profile
    route = lane_ids.duplicate()
    current_route_index = 0
    lane_distance_m = 0.0
    target_speed_mps = profile.maximum_speed_mps
    stop_requested = false
    clear_lead_observation()
    active = true
    _place_on_lane()
    return true

func advance_fixed(delta: float) -> void:
    if not active or delta <= 0.0 or not is_finite(delta):
        return
    var lane := road_graph.get_lane(route[current_route_index])
    if lane == null:
        active = false
        route_rejected.emit("lane_removed")
        return
    var desired_speed: float = minf(minf(target_speed_mps, profile.maximum_speed_mps), lane.speed_limit_mps)
    if stop_requested:
        desired_speed = 0.0
    # Brake before the final endpoint, without overshooting.
    if current_route_index == route.size() - 1:
        var remaining: float = maxf(0.0, lane.length_m() - lane_distance_m)
        desired_speed = minf(desired_speed, sqrt(2.0 * profile.braking_mps2 * remaining))
    if is_finite(lead_gap_m):
        desired_speed = minf(desired_speed, CivicFollowingController.safe_speed(lead_gap_m, lead_speed_mps, profile.braking_mps2, minimum_gap_m, reaction_seconds))
    var rate: float = profile.acceleration_mps2 if desired_speed > speed_mps else profile.braking_mps2
    var next_speed: float = move_toward(speed_mps, desired_speed, rate * delta)
    var travel: float = 0.5 * (speed_mps + next_speed) * delta
    if is_finite(lead_gap_m):
        travel = CivicFollowingController.permitted_travel(travel, lead_gap_m, minimum_gap_m)
        next_speed = minf(next_speed, travel / delta)
    if physics_obstacle_checks_enabled and travel > 0.0 and _path_has_vulnerable_obstacle(travel):
        travel = 0.0
        next_speed = 0.0
    speed_mps = next_speed
    _travel(travel)
    if active:
        _place_on_lane()
    if is_instance_valid(feedback) and feedback.has_method("observe_vehicle"):
        feedback.call("observe_vehicle", speed_mps, active, stop_requested)

## Guard physical vehicles against player, pedestrian and other car penetration.
## Abstract Node3D agents used in deterministic unit tests have no collider;
## they keep the original lane-following behavior.
func _path_has_vulnerable_obstacle(travel: float) -> bool:
    if not is_inside_tree():
        return false
    var collision_body := get_node_or_null("CollisionBody") as StaticBody3D
    if collision_body == null:
        return false
    var collision_shape := collision_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collision_shape == null or collision_shape.shape == null:
        return false
    var original_index := current_route_index
    var original_distance := lane_distance_m
    var remaining := travel
    # Sample the swept path at sub-metre intervals, including turns.
    var samples: int = maxi(1, int(ceil(travel / 0.4)))
    for sample_index in range(1, samples + 1):
        remaining = travel * float(sample_index) / float(samples)
        var index := original_index
        var distance := original_distance
        while index < route.size() - 1:
            var lane: CivicLaneData = road_graph.get_lane(route[index])
            if lane == null:
                return true
            var available := maxf(0.0, lane.length_m() - distance)
            if remaining <= available:
                break
            remaining -= available
            index += 1
            distance = 0.0
        var sampled_lane: CivicLaneData = road_graph.get_lane(route[index])
        if sampled_lane == null:
            return true
        var location: Dictionary = sample_centerline(sampled_lane.centerline, distance + remaining)
        var tangent: Vector3 = location["tangent"]
        var heading := atan2(-tangent.x, -tangent.z)
        var basis := Basis(Vector3.UP, heading)
        if footprint_blocked_at(Transform3D(basis, location["position"])):
            return true
    return false

## Reused by spawn validation and movement: floors support the car,
## while pedestrians, other cars, buildings, walls and street furniture block it.
## This is a footprint *overlap* query, not rigid-body vehicle physics.
func footprint_blocked_at(vehicle_transform: Transform3D) -> bool:
    if not is_inside_tree():
        return false
    var body: StaticBody3D = get_node_or_null("CollisionBody") as StaticBody3D
    if body == null:
        return false
    var collider: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collider == null or collider.shape == null:
        return false
    var shape_transform: Transform3D = vehicle_transform * body.transform * collider.transform
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = collider.shape
    query.transform = shape_transform
    query.collision_mask = 1 | 2 | 4 | 8
    query.exclude = [body.get_rid()]
    query.margin = 0.02
    var car_bottom: float = shape_transform.origin.y - 0.6
    if collider.shape is BoxShape3D:
        car_bottom = shape_transform.origin.y - (collider.shape as BoxShape3D).size.y * 0.5
    var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 32)
    for hit in hits:
        var obstacle: CollisionObject3D = hit.get("collider") as CollisionObject3D
        if obstacle == null:
            continue
        if (obstacle.collision_layer & 1) == 0:
            return true
        # Broad, horizontal terrain/road support is not a traffic obstruction.
        # A sidewalk, building or sign protruding above the tyre clearance is.
        var world_shape: CollisionShape3D = obstacle.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if world_shape == null or not (world_shape.shape is BoxShape3D):
            return true
        var world_box: BoxShape3D = world_shape.shape as BoxShape3D
        var surface_top: float = world_shape.global_position.y + world_box.size.y * 0.5
        if surface_top > car_bottom + 0.035:
            return true
    return false

func _travel(distance: float) -> void:
    var remaining := distance
    while active and remaining > 0.000001:
        var lane := road_graph.get_lane(route[current_route_index])
        var available: float = maxf(0.0, lane.length_m() - lane_distance_m)
        var step: float = minf(remaining, available)
        lane_distance_m += step
        remaining -= step
        if lane_distance_m >= lane.length_m() - 0.000001:
            if current_route_index == route.size() - 1:
                lane_distance_m = lane.length_m()
                speed_mps = 0.0
                active = false
                _place_on_lane()
                route_completed.emit()
                return
            current_route_index += 1
            lane_distance_m = 0.0
        elif step <= 0.0:
            return

func _place_on_lane() -> void:
    if road_graph == null or route.is_empty():
        return
    var lane := road_graph.get_lane(route[current_route_index])
    if lane == null:
        return
    var sampled := sample_centerline(lane.centerline, lane_distance_m)
    global_position = sampled["position"]
    var tangent: Vector3 = sampled["tangent"]
    if tangent.length_squared() > 0.001:
        rotation.y = atan2(-tangent.x, -tangent.z)

static func sample_centerline(points: PackedVector3Array, distance: float) -> Dictionary:
    if points.size() < 2:
        return {"position": Vector3.ZERO, "tangent": Vector3.FORWARD}
    var remaining := maxf(distance, 0.0)
    for index in range(1, points.size()):
        var segment: Vector3 = points[index] - points[index - 1]
        var length: float = segment.length()
        if length <= 0.000001:
            continue
        if remaining <= length or index == points.size() - 1:
            return {"position": points[index - 1] + segment * (clampf(remaining / length, 0.0, 1.0)), "tangent": segment / length}
        remaining -= length
    return {"position": points[points.size() - 1], "tangent": Vector3.FORWARD}
