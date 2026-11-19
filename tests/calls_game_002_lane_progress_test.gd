extends SceneTree
## GAME-002: directed route identity, step progress and fail-closed lifecycle.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Routes = preload("res://scripts/civic/responder_lane_route.gd")
const Response = preload("res://scripts/civic/call_service_response.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        push_error("GAME-002: " + message)

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var lane_a: CivicLaneData = graph.get_lane(1)
    var lane_b: CivicLaneData = graph.get_lane(4)
    var start: Vector3 = Routes._point_at(lane_a, 3.0)
    var finish: Vector3 = Routes._point_at(lane_b, 12.0)
    var plan: Dictionary = Routes.plan(graph, start, finish)
    _check(bool(plan.get("ok", false)), "directed route missing")
    if not bool(plan.get("ok", false)):
        quit(1)
        return
    var ids: PackedInt32Array = plan["lane_ids"]
    var points: PackedVector3Array = plan["points"]
    var indices: PackedInt32Array = plan["lane_indices"]
    var progress: PackedFloat32Array = plan["lane_progress_m"]
    _check(ids == PackedInt32Array([1, 4]), "route must preserve lane identity")
    _check(points.size() == indices.size() and indices.size() == progress.size(), "waypoint metadata sizes differ")
    _check(points.size() > 5, "route lacks bounded step samples")
    for i in range(1, points.size()):
        _check(points[i - 1].distance_to(points[i]) < 1.5, "waypoint step exceeds safe sampler")
        _check(indices[i] >= indices[i - 1], "lane index regressed")
    var reverse: Dictionary = Routes.plan(graph, finish, start)
    if bool(reverse.get("ok", false)):
        _check(reverse["lane_ids"] != PackedInt32Array([4, 1]), "illegal reverse connector accepted")
    _check(not bool(Routes.plan(graph, Vector3(999, 0, 999), finish).get("ok", false)), "off-road spawn accepted")

    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    _check(spawner.configure(graph, 123, false), "traffic spawner setup")
    var signals := Signals.new(12.0, 3.0, 2.0)
    signals.enable_single_approach_mode()
    var reservations := Reservations.new()
    spawner.configure_intersection(signals, reservations)
    var response := Response.new()
    root.add_child(response)
    _check(response.configure_traffic(spawner), "traffic adapter did not bind")
    _check(response.lifecycle_state()["traffic_gate_available"], "callback not available")
    response.route = points
    response._lane_ids = ids
    response._route_lane_indices = indices
    response._route_progress_m = progress
    response.route_index = 1
    response.position = points[0]
    response._probe = BoxShape3D.new()
    response._probe.size = Vector3(1.1, 1.15, 1.9)
    response.active = true
    response.call_id = 91
    response._set_status("EN ROUTE")
    var completed: Array = []
    response.lifecycle_finished.connect(func(id: int, status: String) -> void:
        completed.append({"id": id, "status": status}))
    # Start with non-green and confirm the van cannot cross the stop line.
    signals.advance_fixed(17.0)
    for i in range(160):
        if not response.active:
            break
        response._physics_process(0.1)
    _check(response.position.distance_to(points[0]) > 0.5, "red light blocked all ordinary travel")
    _check(response.position.distance_to(Routes._point_at(lane_a, lane_a.length_m())) > 5.0, "red phase allowed intersection crossing")
    _check(not response.arrived, "red phase completed incident")
    # A withdrawn/replaced call cannot later report an arrival or duplicate completion.
    response._set_status("SERVICE UNAVAILABLE")
    response.retire()
    _check(completed.size() == 1 and completed[0]["id"] == 91, "call withdrawal emitted incorrect event")
    response.retire()
    _check(completed.size() == 1 and not response.active, "replacement retirement was not idempotent")
    _check(not response.lifecycle_state()["traffic_gate_available"], "retired van retained permission callback")
    spawner.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_CALLS_GAME_002_LANE_PROGRESS_PASS")
    else:
        print("CIVIC_CHAOS_CALLS_GAME_002_LANE_PROGRESS_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
