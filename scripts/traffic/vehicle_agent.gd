class_name CivicVehicleAgent
extends Node3D
## Fixed-step lane follower with continuous centerline sampling.

signal route_completed
signal route_rejected(reason: String)

@export var profile: CivicVehicleProfile

var road_graph: CivicRoadGraph
var route: PackedInt32Array = PackedInt32Array()
var current_route_index: int = 0
var lane_distance_m: float = 0.0
var speed_mps: float = 0.0
var target_speed_mps: float = 0.0
var stop_requested: bool = false
var active: bool = false

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
    var desired_speed: float = minf(target_speed_mps, profile.maximum_speed_mps, lane.speed_limit_mps)
    if stop_requested:
        desired_speed = 0.0
    # Brake before the final endpoint, without overshooting.
    if current_route_index == route.size() - 1:
        var remaining: float = maxf(0.0, lane.length_m() - lane_distance_m)
        desired_speed = minf(desired_speed, sqrt(2.0 * profile.braking_mps2 * remaining))
    var rate: float = profile.acceleration_mps2 if desired_speed > speed_mps else profile.braking_mps2
    var next_speed: float = move_toward(speed_mps, desired_speed, rate * delta)
    var travel: float = 0.5 * (speed_mps + next_speed) * delta
    speed_mps = next_speed
    _travel(travel)
    if active:
        _place_on_lane()

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
