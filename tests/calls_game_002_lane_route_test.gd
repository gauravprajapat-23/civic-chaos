extends SceneTree
## GAME-002: lane identities, monotonic progress and fail-closed responder.
const Planner = preload("res://scripts/civic/responder_lane_route.gd")
const Response = preload("res://scripts/civic/call_service_response.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var lane: CivicLaneData = graph.get_lane(100)
    var origin: Vector3 = lane.centerline[0]
    var destination: Vector3 = lane.centerline[lane.centerline.size() - 1]
    var plan: Dictionary = Planner.plan(graph, origin, destination)
    _check(bool(plan.get("ok", false)), "directed route missing")
    if bool(plan.get("ok", false)):
        var ids: PackedInt32Array = plan["lane_ids"]
        var points: PackedVector3Array = plan["points"]
        var indices: PackedInt32Array = plan["lane_indices"]
        var progress: PackedFloat32Array = plan["lane_progress_m"]
        _check(ids.size() >= 1 and points.size() >= 2, "empty vehicle route")
        _check(points.size() == indices.size() and points.size() == progress.size(), "waypoint metadata not aligned")
        for i in range(1, ids.size()):
            _check(graph.outgoing_legal_lanes(ids[i - 1], 1).has(ids[i]), "illegal directed lane transition")
        for i in range(points.size()):
            _check(indices[i] >= 0 and indices[i] < ids.size(), "lane index out of range")
            var segment: CivicLaneData = graph.get_lane(ids[indices[i]])
            _check(progress[i] >= -0.01 and progress[i] <= segment.length_m() + 0.01, "invalid arclength")
            if i > 0 and indices[i] == indices[i - 1]:
                _check(progress[i] + 0.01 >= progress[i - 1], "backward arclength progress")
    _check(not bool(Planner.plan(graph, Vector3(9000, 0, 9000), destination).get("ok", false)), "off-road source accepted")
    var responder: CivicCallServiceResponse = Response.new() as CivicCallServiceResponse
    root.add_child(responder)
    _check(not responder.configure_traffic(null), "null traffic spawner configured")
    responder.route = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -5)])
    responder.route_index = 1
    responder.position = Vector3.ZERO
    responder.active = true
    responder._physics_process(0.1)
    _check(responder.position == Vector3.ZERO, "missing traffic authority allowed movement")
    _check(responder._blocked_seconds > 0.0, "denied movement not accounted")
    responder.retire()
    if failures == 0:
        print("CIVIC_CHAOS_CALLS_GAME_002_LANE_ROUTE_PASS")
    quit(0 if failures == 0 else 1)
