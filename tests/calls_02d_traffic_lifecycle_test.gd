extends SceneTree
## GAME-002: real TRF-002 signal, crossing, spillback and bounded withdrawal.
const Response = preload("res://scripts/civic/call_service_response.gd")
const Adapter = preload("res://scripts/traffic/responder_step_permission.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Priority = preload("res://scripts/traffic/central_intersection_priority.gd")

func _initialize() -> void:
    call_deferred("_run")

func _point(lane: CivicLaneData, distance: float) -> Vector3:
    var remaining: float = distance
    for i in range(1, lane.centerline.size()):
        var a: Vector3 = lane.centerline[i - 1]
        var b: Vector3 = lane.centerline[i]
        var length: float = a.distance_to(b)
        if remaining <= length:
            return a.lerp(b, clampf(remaining / maxf(length, 0.00001), 0.0, 1.0))
        remaining -= length
    return lane.centerline[-1]

func _fixture(spawner: CivicTrafficSpawner, origin: Vector3,
        goal: Vector3, distance: float) -> CivicCallServiceResponse:
    var response := Response.new() as CivicCallServiceResponse
    root.add_child(response)
    response._probe = BoxShape3D.new()
    response._probe.size = Vector3(1.1, 1.15, 1.9)
    response.call_id = 68
    response.active = true
    response.route = PackedVector3Array([origin, goal])
    response.route_index = 1
    response.position = origin
    response.stop_point = goal
    response._lane_ids = PackedInt32Array([1, 4])
    response._route_lane_indices = PackedInt32Array([0, 0])
    response._route_progress_m = PackedFloat32Array([distance, distance + 0.65])
    response.configure_traffic(spawner)
    return response

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var inbound: CivicLaneData = graph.get_lane(1)
    var distance: float = inbound.length_m() - 6.5
    var start: Vector3 = _point(inbound, distance)
    var finish: Vector3 = _point(inbound, distance + 0.65)
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 333, false):
        _fail("traffic spawner setup")
        return
    var van := _fixture(spawner, start, finish, distance)
    var statuses: Array[String] = []
    van.lifecycle_finished.connect(func(_id: int, status: String) -> void:
        statuses.append(status))
    van._physics_process(0.1)
    if van.position.distance_to(start) > 0.001 or van._blocked_seconds <= 0:
        _fail("missing signals incorrectly allowed a junction step")
        return
    var signals := Signals.new(12.0, 3.0, 2.0)
    signals.enable_single_approach_mode()
    var reservations := Reservations.new()
    spawner.configure_intersection(signals, reservations)
    var approach: String = Spawner.signal_approach_for_lane(inbound, false)
    for i in range(4):
        if signals.aspect_for_approach(approach) == "green":
            break
        signals.advance_fixed(17.0)
    if signals.aspect_for_approach(approach) != "green":
        _fail("no usable green aspect")
        return
    var zone: String = Spawner.crossing_conflict_zone(approach)
    if not bool(reservations.request(711, PackedStringArray([zone]), 0, 100).get("granted", false)) or not reservations.occupy(711, zone):
        _fail("crossing setup failed")
        return
    van._physics_process(0.1)
    if van.position.distance_to(start) > 0.001:
        _fail("occupied crossing allowed responder movement")
        return
    reservations.release(711, zone)
    reservations.cancel(711)
    var downstream := CivicVehicleAgent.new()
    downstream.route = PackedInt32Array([4])
    downstream.current_route_index = 0
    downstream.lane_distance_m = Priority.OUTBOUND_QUEUE_CLEARANCE_M - 0.5
    downstream.active = true
    spawner.register_road_user(downstream)
    van._physics_process(0.1)
    if van.position.distance_to(start) > 0.001:
        _fail("outbound spillback allowed responder movement")
        return
    spawner.unregister_road_user(downstream)
    downstream.free()
    # A real green and cleared junction must release progress.
    van._physics_process(0.1)
    if van.position.distance_to(start) < 0.01:
        _fail("green release failed to resume response")
        return
    # A replaced/expired call never continues travelling or pays rewards.
    van._set_status("SERVICE UNAVAILABLE")
    van.retire()
    var retired: Vector3 = van.position
    van._physics_process(0.1)
    if van.active or van.position != retired or statuses != ["SERVICE UNAVAILABLE"]:
        _fail("retired call continued or emitted duplicate terminal outcome")
        return
    var expired := _fixture(spawner, start, finish, distance)
    expired._blocked_seconds = expired.ABORT_BLOCKED_S - 0.05
    signals.advance_fixed(12.0) # amber is never permission
    expired._physics_process(0.1)
    if expired.active or expired.response_status != "SERVICE UNAVAILABLE":
        _fail("bounded red-light wait did not withdraw call")
        return
    spawner.queue_free()
    print("CIVIC_CHAOS_CALLS_02D_TRAFFIC_LIFECYCLE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
