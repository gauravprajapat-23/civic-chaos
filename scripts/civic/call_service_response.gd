class_name CivicCallServiceResponse
extends Node3D
## CALLS-02: one visual municipal response van traveling along the real
## city road graph. This is NOT incident completion, traffic priority,
## an ambulance, or an instant-spawn reward.
signal status_changed(status: String)
signal lifecycle_finished(call_id: int, final_status: String)

## Optional Traffic-owned permission gate. A false response holds the van;
## this worker never grants signal priority or changes junction phases.
var traffic_step_permission: Callable = Callable()
var _traffic_gate_configured: bool = false
var _traffic_adapter: CivicResponderStepPermission
var _lane_ids: PackedInt32Array = PackedInt32Array()
var _route_lane_indices: PackedInt32Array = PackedInt32Array()
var _route_progress_m: PackedFloat32Array = PackedFloat32Array()
var _terminal_status: String = ""
var _traffic_adapter: RefCounted
var _road_graph: CivicRoadGraph
var _lane_ids: PackedInt32Array = PackedInt32Array()
var _leg_lanes: PackedInt32Array = PackedInt32Array()

const LaneRoutes = preload("res://scripts/civic/responder_lane_route.gd")
const TrafficPermission = preload("res://scripts/traffic/responder_step_permission.gd")
const SERVICE_SPEED_MPS: float = 5.5
const ARRIVAL_DISTANCE_M: float = 0.5
const BLOCKED_NOTICE_S: float = 2.5
const ABORT_BLOCKED_S: float = 18.0
const ON_SCENE_HOLD_S: float = 9.0
const SERVICE_ORIGIN: Vector3 = Vector3(-46.0, 0.0, -46.0)
const VALID_SERVICES: Dictionary = {
    "civic_litter": "SANITATION",
    "fallen_public_sign": "MAINTENANCE",
    "misplaced_safety_cone": "ROAD SAFETY"
}

var call_id: int = -1
var service_label: String = ""
var target: Vector3 = Vector3.ZERO
var active: bool = false
var arrived: bool = false
var route: PackedVector3Array = PackedVector3Array()
var route_index: int = 1
var _van: StaticBody3D
var stop_point: Vector3 = Vector3.ZERO
var _blocked_seconds: float = 0.0
var _on_scene_seconds: float = 0.0
var response_status: String = ""
var _probe: BoxShape3D

func _init() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

static func service_for(kind: String) -> String:
    return str(VALID_SERVICES.get(kind, ""))

## Choose a real-road shoulder from the lane geometry. Never use the
## incident object itself as a vehicle destination: it may be on a
## footpath or beside a building. Search nearby lane segments and sample
## curb-side offsets *within* the city's 8m road width.
static func roadside_candidates(graph: CivicRoadGraph, incident: Vector3) -> Array[Vector3]:
    var ranked: Array[Dictionary] = []
    if graph == null or not incident.is_finite():
        return []
    for lane_id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(lane_id)
        if lane == null or lane.is_wrong_way_connector:
            continue
        for i in range(1, lane.centerline.size()):
            var a: Vector3 = lane.centerline[i - 1]
            var b: Vector3 = lane.centerline[i]
            var along: Vector3 = b - a
            along.y = 0.0
            if along.length_squared() < 0.01:
                continue
            var lateral := Vector3(-along.z, 0.0, along.x).normalized()
            for t in [0.25, 0.5, 0.75]:
                var mid: Vector3 = a.lerp(b, t)
                for shift in [-1.65, 1.65, -2.2, 2.2]:
                    var candidate: Vector3 = mid + lateral * shift
                    candidate.y = 0.12
                    var distance: float = Vector2(candidate.x - incident.x,
                        candidate.z - incident.z).length()
                    if distance < 3.0 or distance > 18.0:
                        continue
                    ranked.append({"point": candidate, "distance": distance})
    ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["distance"]) < float(b["distance"]))
    var output: Array[Vector3] = []
    for item in ranked:
        var point: Vector3 = item["point"]
        var duplicate: bool = false
        for existing in output:
            if existing.distance_to(point) < 1.5:
                duplicate = true
                break
        if not duplicate:
            output.append(point)
        if output.size() >= 18:
            break
    return output

func _set_status(value: String) -> void:
    if response_status == value:
        return
    response_status = value
    status_changed.emit(value)

func configure(graph: CivicRoadGraph, incident_id: int, kind: String,
        at: Vector3) -> bool:
    if active or call_id > 0 or graph == null or incident_id <= 0 or (
            not at.is_finite()) or service_for(kind).is_empty() or (
            not is_inside_tree()):
        return false
    _probe = BoxShape3D.new()
    _probe.size = Vector3(1.1, 1.15, 1.9)
    # Reject full road occupation at both ends, then choose the
    # nearest physically clear shoulder for the real incident.
    var candidate_origins: Array[Vector3] = [
        SERVICE_ORIGIN, Vector3(-46, 0, 0),
        Vector3(0, 0, -46), Vector3(46, 0, -46)
    ]
    var points := PackedVector3Array()
    var spawn := Vector3.ZERO
    var selected_stop := Vector3.ZERO
    var selected_lanes := PackedInt32Array()
    var selected_legs := PackedInt32Array()
    var selected_plan: Dictionary = {}
    var stops: Array[Vector3] = roadside_candidates(graph, at)
    for roadside in stops:
        if not _space_clear(roadside, true):
            continue
        for depot in candidate_origins:
            var candidate := Vector3(depot.x, 0.12, depot.z)
            if candidate.distance_to(roadside) < 3.0 or not _space_clear(candidate, true):
                continue
            var proposed: Dictionary = LaneRoutes.plan(graph, candidate, roadside)
            if not bool(proposed.get("ok", false)):
                continue
            var proposed_points: PackedVector3Array = proposed.get(
                "points", PackedVector3Array())
            if proposed_points.size() < 2:
                continue
            spawn = candidate
            selected_stop = roadside
            points = proposed_points
            selected_plan = proposed
            break
        if points.size() >= 2:
            break
    if points.size() < 2 or selected_lanes.is_empty() or selected_legs.size() != points.size() - 1:
        return false
    _road_graph = graph
    _lane_ids = selected_lanes
    _leg_lanes = selected_legs
    call_id = incident_id
    service_label = service_for(kind)
    target = at
    stop_point = points[-1]
    route = points
    _lane_ids = selected_plan["lane_ids"]
    _route_lane_indices = selected_plan["lane_indices"]
    _route_progress_m = selected_plan["lane_progress_m"]
    route_index = 1
    position = points[0]
    _build_visual()
    active = true
    _set_status("EN ROUTE")
    return true

func _build_visual() -> void:
    _van = StaticBody3D.new()
    _van.name = "MunicipalServiceVehicle"
    _van.collision_layer = 4
    _van.collision_mask = 0
    add_child(_van)
    var collider := CollisionShape3D.new()
    collider.name = "CollisionShape3D"
    collider.shape = _probe
    collider.position.y = 0.7
    _van.add_child(collider)
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.93, 0.73, 0.20)
    paint.metallic = 0.12
    var body := MeshInstance3D.new()
    body.name = "MunicipalServiceVan"
    var box := BoxMesh.new()
    box.size = Vector3(1.15, 0.9, 1.95)
    body.mesh = box
    body.position.y = 0.75
    body.material_override = paint
    _van.add_child(body)
    var tire_material := StandardMaterial3D.new()
    tire_material.albedo_color = Color(0.08, 0.09, 0.11)
    for side in [-1.0, 1.0]:
        for axle in [-0.58, 0.58]:
            var wheel := MeshInstance3D.new()
            wheel.name = "Wheel_%d_%d" % [int(side), int(axle * 100)]
            var tire := CylinderMesh.new()
            tire.top_radius = 0.27
            tire.bottom_radius = 0.27
            tire.height = 0.13
            wheel.mesh = tire
            wheel.material_override = tire_material
            wheel.position = Vector3(side * 0.57, 0.35, axle)
            wheel.rotation.z = PI * 0.5
            _van.add_child(wheel)
    var stripe := MeshInstance3D.new()
    stripe.name = "ServiceRoofBeacon"
    var lamp := BoxMesh.new()
    lamp.size = Vector3(0.56, 0.16, 0.32)
    stripe.mesh = lamp
    stripe.position.y = 1.28
    var amber := StandardMaterial3D.new()
    amber.albedo_color = Color(0.99, 0.43, 0.08)
    amber.emission_enabled = true
    amber.emission = amber.albedo_color
    stripe.material_override = amber
    _van.add_child(stripe)
    var label := Label3D.new()
    label.name = "ServiceLabel"
    label.text = service_label
    label.font_size = 30
    label.pixel_size = 0.005
    label.position = Vector3(0, 1.65, 0)
    _van.add_child(label)

## Only actual obstacles at van height block the next step.
## Ground/sidewalk support is below the probe, so no collision bypass
## for walls, traffic, pedestrians, props or mounted motorcycles.
func _space_clear(at: Vector3, spawning: bool = false) -> bool:
    if not is_inside_tree():
        return false
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _probe
    query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.76)
    query.collision_mask = 1 | 2 | 4 | 8 | 16
    if not spawning and is_instance_valid(_van):
        query.exclude = [_van.get_rid()]
    query.margin = 0.03
    return get_world_3d().direct_space_state.intersect_shape(query, 12).is_empty()

## Bind the authoritative Traffic adapter for the lifetime of this responder.
## The Main-owned integration must provide its real configured spawner.
## A failed or invalid binding permanently fails closed until reconfigured.
func configure_traffic(spawner: CivicTrafficSpawner) -> bool:
    _traffic_gate_configured = true
    traffic_step_permission = Callable()
    _traffic_adapter = TrafficPermission.new()
    if not _traffic_adapter.configure(spawner):
        return false
    traffic_step_permission = Callable(_traffic_adapter, "allows_step")
    return true

## Traffic may supply a callable (from_position, to_position) -> bool.
## A never-configured gate preserves CALLS-02 compatibility. Once configured,
## invalidation of Traffic's owner must never become an implicit green light.
## Traffic owns lane/intersection resolution; this callable is not authoritative
## until TRF-002 supplies its fail-closed route/lane mapping.
func set_traffic_step_permission(permission: Callable) -> void:
    _traffic_gate_configured = true
    traffic_step_permission = permission

## Main configures one Traffic-owned adapter per responder and keeps a strong
## reference here until retirement. An unavailable configured adapter denies steps.
func configure_traffic_adapter(adapter: RefCounted) -> bool:
    _traffic_adapter = adapter
    set_traffic_step_permission(Callable())
    if adapter == null or not adapter.has_method("set_route_context") or not adapter.has_method("allows_step"):
        return false
    set_traffic_step_permission(Callable(adapter, "allows_step"))
    return true

func lane_route_state() -> Dictionary:
    return {"lane_ids": _lane_ids.duplicate(), "leg_lanes": _leg_lanes.duplicate(),
        "leg_index": route_index - 1}

func _permission_context_ready() -> bool:
    if not _traffic_gate_configured:
        return true
    if _traffic_adapter == null or not traffic_step_permission.is_valid():
        return false
    if _road_graph == null or route_index < 1 or route_index > _leg_lanes.size():
        return false
    var leg: int = route_index - 1
    var lane_index: int = _leg_lanes[leg]
    if lane_index < 0 or lane_index >= _lane_ids.size():
        return false
    var lane: CivicLaneData = _road_graph.get_lane(_lane_ids[lane_index])
    if lane == null:
        return false
    var location: Dictionary = LaneRoutes._project(lane, position)
    if float(location["lateral_m"]) > 2.5:
        return false
    return bool(_traffic_adapter.call("set_route_context",
        _lane_ids, lane_index, float(location["distance_m"])))

func lifecycle_state() -> Dictionary:
    return {"call_id": call_id, "active": active, "arrived": arrived,
        "status": response_status, "terminal_status": _terminal_status,
        "position": position, "stop_point": stop_point,
        "route_index": route_index, "route_size": route.size(),
        "lane_route_size": _lane_ids.size(),
        "traffic_gate_configured": _traffic_gate_configured,
        "traffic_gate_available": traffic_step_permission.is_valid(),
        "lane_count": _lane_ids.size(), "current_leg": route_index - 1}

func _finish_on_scene() -> void:
    arrived = true
    _on_scene_seconds = 0.0
    _set_status("ON SCENE")

## Validate the complete swept trajectory (not just the endpoint) so a
## larger physics delta cannot tunnel a responder through a pedestrian.
func _step_is_clear(start: Vector3, finish: Vector3) -> bool:
    var gap: Vector3 = finish - start
    var steps: int = maxi(1, int(ceil(gap.length() / 0.20)))
    for i in range(1, steps + 1):
        if not _space_clear(start.lerp(finish, float(i) / float(steps))):
            return false
    return true

func _physics_process(delta: float) -> void:
    if not active or delta <= 0.0:
        return
    if arrived:
        _on_scene_seconds += delta
        if _on_scene_seconds >= ON_SCENE_HOLD_S:
            # Do not leave a permanent parked vehicle to cause gridlock.
            _set_status("SERVICE CLEARED")
            retire()
        return
    if route_index >= route.size():
        _finish_on_scene()
        return
    var waypoint: Vector3 = route[route_index]
    var remaining := Vector3(waypoint.x - position.x, 0,
        waypoint.z - position.z)
    if remaining.length() < 0.20:
        route_index += 1
        if route_index >= route.size():
            _finish_on_scene()
        return
    var movement: Vector3 = remaining.normalized() * minf(
        remaining.length(), SERVICE_SPEED_MPS * minf(delta, 0.10))
    var next: Vector3 = position + movement
    # Refresh Traffic context from the exact directed route waypoint. The
    # adapter verifies geometry; a missing/stale owner never grants entry.
    var context_ok: bool = true
    if _traffic_adapter != null:
        var step_index: int = route_index - 1
        context_ok = step_index >= 0 and step_index < _route_lane_indices.size()
        if context_ok:
            context_ok = _traffic_adapter.set_route_context(_lane_ids,
                _route_lane_indices[step_index], float(_route_progress_m[step_index]))
    var traffic_permitted: bool = not _traffic_gate_configured
    if _traffic_gate_configured and context_ok:
        traffic_permitted = traffic_step_permission.is_valid() and bool(traffic_step_permission.call(position, next))
    if not traffic_permitted or not _step_is_clear(position, next):
        _blocked_seconds += delta
        if _blocked_seconds >= ABORT_BLOCKED_S:
            _set_status("SERVICE UNAVAILABLE")
            retire()
        elif _blocked_seconds >= BLOCKED_NOTICE_S:
            _set_status("WAITING FOR CLEAR ROAD")
        return
    _blocked_seconds = 0.0
    if response_status == "WAITING FOR CLEAR ROAD":
        _set_status("EN ROUTE")
    position = next
    rotation.y = atan2(-movement.x, -movement.z)
    # Nearness to the incident never counts as arrival. The actual van
    # must reach its validated roadside stopping point.
    if route_index == route.size() - 1 and (
            Vector2(position.x - stop_point.x,
            position.z - stop_point.z).length() <= ARRIVAL_DISTANCE_M):
        _finish_on_scene()

func retire() -> void:
    if not active:
        return
    active = false
    if _traffic_adapter != null and _traffic_adapter.has_method("clear_context"):
        _traffic_adapter.call("clear_context")
    traffic_step_permission = Callable()
    _traffic_adapter = null
    _terminal_status = response_status
    lifecycle_finished.emit(call_id, _terminal_status)
    if _traffic_adapter != null:
        _traffic_adapter.clear_context()
    _traffic_adapter = null
    traffic_step_permission = Callable()
    if is_instance_valid(_van):
        _van.collision_layer = 0
        _van.collision_mask = 0
    queue_free()
