extends SceneTree
## GAME-002: authoritative directed lane IDs and monotonic arclength at
## every waypoint, including a legal intersection lane change.
const Planner = preload("res://scripts/civic/responder_lane_route.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _point(lane: CivicLaneData, meters: float) -> Vector3:
    return Planner._point_at(lane, meters)

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var inbound: CivicLaneData = graph.get_lane(1)
    var outbound: CivicLaneData = graph.get_lane(4)
    if inbound == null or outbound == null or not graph.outgoing_legal_lanes(1, 1).has(4):
        _fail("directed junction fixture missing")
        return
    var start: Vector3 = _point(inbound, inbound.length_m() - 5.0)
    var goal: Vector3 = _point(outbound, minf(10.0, outbound.length_m() - 0.2))
    var plan: Dictionary = Planner.plan(graph, start, goal)
    if not bool(plan.get("ok", false)):
        _fail("legal lane route planner rejected junction")
        return
    var lane_ids: PackedInt32Array = plan["lane_ids"]
    var points: PackedVector3Array = plan["points"]
    var indices: PackedInt32Array = plan["lane_indices"]
    var distances: PackedFloat32Array = plan["lane_progress_m"]
    if lane_ids != PackedInt32Array([1, 4]) or points.size() < 3 or (
            indices.size() != points.size()) or distances.size() != points.size():
        _fail("lane route lost directed lane provenance")
        return
    var saw_transition: bool = false
    for i in range(points.size()):
        if indices[i] < 0 or indices[i] >= lane_ids.size():
            _fail("waypoint references nonexistent lane")
            return
        var lane: CivicLaneData = graph.get_lane(lane_ids[indices[i]])
        var projection: Dictionary = Planner._projection(lane, points[i])
        if float(projection["offset"]) > 2.5 or (
                absf(float(projection["distance"]) - distances[i]) > 0.2):
            _fail("waypoint projection does not match authoritative lane progress")
            return
        if i > 0:
            if indices[i] < indices[i - 1] or indices[i] > indices[i - 1] + 1:
                _fail("lane sequence skipped or reversed")
                return
            if indices[i] == indices[i - 1] and distances[i] + 0.1 < distances[i - 1]:
                _fail("same-lane progress reversed")
                return
            if indices[i] > indices[i - 1]:
                saw_transition = true
    if not saw_transition:
        _fail("directed route never entered outbound lane")
        return
    var wrong_direction: Dictionary = Planner.plan(graph, goal, start)
    if bool(wrong_direction.get("ok", false)):
        var reverse_ids: PackedInt32Array = wrong_direction["lane_ids"]
        if reverse_ids == PackedInt32Array([4, 1]):
            _fail("wrong-way shortcut accepted as legal directed transition")
            return
    print("CIVIC_CHAOS_CALLS_02D_DIRECTED_ROUTE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
