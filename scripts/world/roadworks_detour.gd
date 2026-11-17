class_name CivicRoadworksDetour
extends Node3D
## MAP-CHALLENGE-02: deterministic temporary closure of ONE empty
## outer-city directed lane. The alternative route remains traversable.
## Signs/cones are visual-only; live drivers are never trapped by props.
signal changed(message: String)
const Router = preload("res://scripts/traffic/lane_router.gd")
const OWNER: String = "map_challenge_02_roadworks"
const FIRST_TICK: int = 1200
const REPEAT_TICKS: int = 3600
const DURATION_TICKS: int = 1200
const CANDIDATE_STARTS = [
    Vector3(120, 0, 46), Vector3(-120, 0, -46),
    Vector3(46, 0, 120), Vector3(-46, 0, -120)
]
const CANDIDATE_ENDS = [
    Vector3(120, 0, 120), Vector3(-120, 0, -120),
    Vector3(120, 0, 120), Vector3(-120, 0, -120)
]

var traffic: CivicTrafficSpawner
var graph: CivicRoadGraph
var lane_id: int = -1
var start_tick: int = -1
var finish_tick: int = -1
var completed_before: int = 0
var next_event_tick: int = FIRST_TICK
var event_number: int = 0
var last_seen_tick: int = -1
var _signs: Node3D

func configure(spawner: CivicTrafficSpawner) -> bool:
    if spawner == null or spawner.road_graph == null or not spawner.city_mode:
        return false
    traffic = spawner
    graph = spawner.road_graph
    last_seen_tick = -1
    return true

func active() -> bool:
    return lane_id >= 0 and traffic != null and traffic.route_lane_closed(lane_id)

func advance_to(tick: int) -> void:
    if traffic == null or graph == null:
        return
    if last_seen_tick >= 0 and tick < last_seen_tick:
        # F9 rollback: a roadworks event is transient, not part of the
        # atomic traffic save. Retire stale closure and wait to reschedule.
        if active():
            _finish("Roadworks reset after checkpoint restore.")
        next_event_tick = tick + 200
    last_seen_tick = tick
    if active():
        if tick >= finish_tick:
            _finish("Roadworks completed; street reopened.")
        return
    if tick < next_event_tick:
        return
    # Avoid repeatedly retrying every frame when the street is occupied.
    # Try again in 10s and pick a different safe segment next cycle.
    next_event_tick = tick + 200
    for offset in range(CANDIDATE_STARTS.size()):
        var option: int = (event_number + offset) % CANDIDATE_STARTS.size()
        var candidate: int = _find_lane(CANDIDATE_STARTS[option], CANDIDATE_ENDS[option])
        if candidate < 0 or traffic.route_lane_closed(candidate) or _route_has_live_car(candidate):
            continue
        if not _has_detour(candidate):
            continue
        if traffic.set_incident_route_closure(OWNER, candidate):
            lane_id = candidate
            start_tick = tick
            finish_tick = tick + DURATION_TICKS
            completed_before = traffic.completed_total
            event_number = option + 1
            _show_worksite()
            changed.emit("ROADWORKS | Outer street closed. Follow the alternate route; ask the marshal to reopen after two real arrivals.")
            return

func request_player_reopen() -> Dictionary:
    if not active():
        return {"accepted": false, "reason": "no_active_roadworks"}
    if traffic.completed_total - completed_before < 2:
        return {"accepted": false, "reason": "need_two_real_arrivals"}
    # No one can be removed by this operation; reopen only the lane
    # this roadworks actor actually closed.
    _finish("Traffic Marshal | Detour verified; roadworks cleared safely.")
    return {"accepted": true, "reason": "detour_verified"}

func _finish(message: String) -> void:
    if traffic != null:
        traffic.clear_incident_route_closure(OWNER)
    lane_id = -1
    start_tick = -1
    finish_tick = -1
    if is_instance_valid(_signs):
        _signs.queue_free()
    _signs = null
    next_event_tick = maxi(next_event_tick, traffic.current_tick + REPEAT_TICKS) if traffic != null else REPEAT_TICKS
    changed.emit(message)

func _find_lane(start: Vector3, finish: Vector3) -> int:
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if lane.centerline[0].distance_to(start) < 0.1 and lane.centerline[-1].distance_to(finish) < 0.1:
            return id
    return -1

func _route_has_live_car(candidate: int) -> bool:
    for car in traffic.traffic_road_users():
        if not is_instance_valid(car) or not car.active:
            continue
        for route_index in range(car.current_route_index, car.route.size()):
            if car.route[route_index] == candidate:
                return true
    return false

func _has_detour(candidate: int) -> bool:
    var lane: CivicLaneData = graph.get_lane(candidate)
    if lane == null:
        return false
    var destination: Vector3 = lane.centerline[-1]
    var routes: Array[int] = graph.outgoing_legal_lanes(candidate, 1)
    # Find an alternative between the same source and destination via
    # neighboring streets, not an imaginary edge or opposite-side U-turn.
    for start_id in graph.sorted_lane_ids():
        var start_lane: CivicLaneData = graph.get_lane(start_id)
        if start_lane.centerline[0].distance_to(lane.centerline[0]) > 0.1:
            continue
        if start_id == candidate or traffic.route_lane_closed(start_id):
            continue
        for goal_id in graph.sorted_lane_ids():
            var goal_lane: CivicLaneData = graph.get_lane(goal_id)
            if goal_lane.centerline[-1].distance_to(destination) > 0.1:
                continue
            if goal_id == candidate or traffic.route_lane_closed(goal_id):
                continue
            var blocked := PackedInt32Array([candidate])
            var found: Dictionary = Router.new(graph).find_route(start_id, goal_id, 1, blocked)
            if bool(found.get("ok", false)) and (found["path"] as PackedInt32Array).size() >= 2:
                return true
    return false

func _show_worksite() -> void:
    if not is_inside_tree() or graph == null:
        return
    var lane: CivicLaneData = graph.get_lane(lane_id)
    _signs = Node3D.new()
    _signs.name = "RoadworksWarning"
    add_child(_signs)
    var forward: Vector3 = (lane.centerline[-1] - lane.centerline[0]).normalized()
    var right: Vector3 = Vector3(-forward.z, 0, forward.x)
    var where: Vector3 = lane.centerline[0].lerp(lane.centerline[-1], 0.5)
    # Shoulder location outside carriageway. No physical colliders.
    for side in [-1.0, 1.0]:
        var post := MeshInstance3D.new()
        post.name = "WarningPost_%d" % int(side)
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.08
        mesh.bottom_radius = 0.08
        mesh.height = 1.8
        post.mesh = mesh
        post.position = where + right * (5.8 * side) + Vector3.UP * 0.9
        _signs.add_child(post)
        var notice := Label3D.new()
        notice.name = "DetourLabel_%d" % int(side)
        notice.text = "ROADWORKS\nDETOUR"
        notice.font_size = 42
        notice.pixel_size = 0.005
        notice.position = post.position + Vector3.UP * 1.25
        _signs.add_child(notice)
    # Cones mark a visually narrowed shoulder approach. They have no
    # physics collision; only the authoritative lane closure affects NPC
    # route choice, preventing another invisible-barrier/gridlock defect.
    for index in range(5):
        var cone := MeshInstance3D.new()
        cone.name = "WorkCone_%d" % index
        var cone_mesh := CylinderMesh.new()
        cone_mesh.top_radius = 0.08
        cone_mesh.bottom_radius = 0.28
        cone_mesh.height = 0.65
        cone.mesh = cone_mesh
        cone.position = where + forward * (float(index - 2) * 2.0) + right * 4.4 + Vector3.UP * 0.33
        var orange := StandardMaterial3D.new()
        orange.albedo_color = Color(1.0, 0.44, 0.07)
        cone.material_override = orange
        _signs.add_child(cone)
