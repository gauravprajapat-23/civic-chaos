extends SceneTree
## GAME-002: directed route identity, step progress and fail-closed lifecycle.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Routes = preload("res://scripts/civic/responder_lane_route.gd")
const Response = preload("res://scripts/civic/call_service_response.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Priority = preload("res://scripts/traffic/central_intersection_priority.gd")
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
    # Exercise the responder-owned Traffic callback at a real stop line.
    var check_distance: float = lane_a.length_m() - 6.5
    var before: Vector3 = Routes._point_at(lane_a, check_distance)
    var after: Vector3 = Routes._point_at(lane_a, check_distance + 0.7)
    var gate: CivicResponderStepPermission = response._traffic_adapter
    _check(gate.set_route_context(ids, 0, check_distance), "responder route context invalid")
    _check(gate.allows_step(before, after), "green signal denied safe entry")
    signals.advance_fixed(12.0)
    _check(not gate.allows_step(before, after), "amber bypassed")
    signals.advance_fixed(3.0)
    _check(not gate.allows_step(before, after), "all-red bypassed")
    signals.advance_fixed(2.0)
    var approach: String = Spawner.signal_approach_for_lane(lane_a, false)
    for i in range(4):
        if signals.aspect_for_approach(approach) == "green":
            break
        signals.advance_fixed(17.0)
    _check(signals.aspect_for_approach(approach) == "green", "green cycle recovery")
    var zone: String = Spawner.crossing_conflict_zone(approach)
    _check(bool(reservations.request(501, PackedStringArray([zone]), 0, 100).get("granted", false)),
        "crossing reservation failed")
    _check(reservations.occupy(501, zone), "crossing occupancy failed")
    _check(not gate.allows_step(before, after), "occupied pedestrian crossing bypassed")
    reservations.release(501, zone)
    reservations.cancel(501)
    var downstream := CivicVehicleAgent.new()
    downstream.route = PackedInt32Array([4])
    downstream.current_route_index = 0
    downstream.lane_distance_m = Priority.OUTBOUND_QUEUE_CLEARANCE_M - 0.5
    downstream.active = true
    spawner.register_road_user(downstream)
    _check(not gate.allows_step(before, after), "blocked outbound lane bypassed")
    downstream.lane_distance_m = Priority.OUTBOUND_QUEUE_CLEARANCE_M + 0.5
    _check(gate.allows_step(before, after), "downstream recovery remained blocked")
    downstream.route = ids
    downstream.current_route_index = 0
    downstream.lane_distance_m = lane_a.length_m() - 3.0
    _check(not gate.allows_step(before, after), "committed central car bypassed")
    spawner.unregister_road_user(downstream)
    downstream.free()
    _check(gate.allows_step(before, after), "cleared central junction remained held")
    # Preserve red for responder movement simulation below.
    signals.advance_fixed(12.0)
    signals.advance_fixed(3.0)
    signals.advance_fixed(2.0)
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
    var replaced := Response.new()
    root.add_child(replaced)
    var expired_events: Array = []
    replaced.lifecycle_finished.connect(func(id: int, status: String) -> void:
        expired_events.append({"id": id, "status": status}))
    replaced.call_id = 92
    replaced.active = true
    replaced._set_status("WAITING FOR CLEAR ROAD")
    replaced.retire()
    replaced.retire()
    _check(expired_events.size() == 1, "expired call emitted repeated lifecycle events")
    _check(expired_events[0]["id"] == 92 and expired_events[0]["status"] == "SERVICE WITHDRAWN",
        "expired/replaced call did not receive terminal withdrawal")
    _check(not replaced.arrived and not replaced.active, "expired call falsely arrived")
    spawner.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_CALLS_GAME_002_LANE_PROGRESS_PASS")
    else:
        print("CIVIC_CHAOS_CALLS_GAME_002_LANE_PROGRESS_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
