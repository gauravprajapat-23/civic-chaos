extends SceneTree
## TRF-002: authoritative route context, signal, reservation, physical
## central occupancy, downstream capacity, and non-junction progress.
const Adapter = preload("res://scripts/traffic/responder_step_permission.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Priority = preload("res://scripts/traffic/central_intersection_priority.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 333, false):
        _fail("graph setup")
        return
    var gate := Adapter.new() as CivicResponderStepPermission
    if not gate.configure(spawner):
        _fail("adapter setup")
        return
    var inbound: CivicLaneData = graph.get_lane(1)
    var route := PackedInt32Array([1, 4])
    var before: float = inbound.length_m() - 6.5
    var start: Vector3 = _point(inbound, before)
    var next: Vector3 = _point(inbound, before + 0.7)
    if gate.allows_step(start, next):
        _fail("missing context permitted junction")
        return
    if not gate.set_route_context(route, 0, before):
        _fail("valid route rejected")
        return
    if gate.allows_step(start, next):
        _fail("missing controller permitted junction")
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
    if signals.aspect_for_approach(approach) != "green" or not gate.allows_step(start, next):
        _fail("clear green failed to release responder")
        return
    signals.advance_fixed(12.0)
    if gate.allows_step(start, next):
        _fail("amber permitted junction entry")
        return
    signals.advance_fixed(3.0)
    if gate.allows_step(start, next):
        _fail("all-red permitted junction entry")
        return
    signals.advance_fixed(2.0)
    for i in range(4):
        if signals.aspect_for_approach(approach) == "green":
            break
        signals.advance_fixed(17.0)
    if signals.aspect_for_approach(approach) != "green":
        _fail("unable to return to green")
        return
    var zone: String = Spawner.crossing_conflict_zone(approach)
    if not bool(reservations.request(711, PackedStringArray([zone]), 0, 100).get("granted", false)) or not reservations.occupy(711, zone):
        _fail("pedestrian reservation setup")
        return
    if gate.allows_step(start, next):
        _fail("occupied crossing permitted entry")
        return
    reservations.release(711, zone)
    reservations.cancel(711)
    if not gate.allows_step(start, next):
        _fail("crossing release did not unblock entry")
        return
    var downstream := _car(PackedInt32Array([4]), Priority.OUTBOUND_QUEUE_CLEARANCE_M - 0.5)
    spawner.register_road_user(downstream)
    if gate.allows_step(start, next):
        _fail("downstream spillback permitted entry")
        return
    downstream.lane_distance_m = Priority.OUTBOUND_QUEUE_CLEARANCE_M + 0.5
    if not gate.allows_step(start, next):
        _fail("exit clearance did not unblock entry")
        return
    downstream.route = route
    downstream.current_route_index = 0
    downstream.lane_distance_m = inbound.length_m() - 3.0
    if gate.allows_step(start, next):
        _fail("committed central vehicle ignored")
        return
    spawner.unregister_road_user(downstream)
    downstream.free()
    if not gate.allows_step(start, next):
        _fail("cleared junction remained blocked")
        return
    if gate.allows_step(Vector3(500, 0, 500), Vector3(500.5, 0, 500)):
        _fail("unmappable movement was allowed")
        return
    if gate.allows_step(start, start + Vector3(8, 0, 0)):
        _fail("large ambiguous step was allowed")
        return
    if not gate.set_route_context(route, 0, 0.0) or gate.allows_step(start, next):
        _fail("stale progress was allowed")
        return
    if gate.set_route_context(PackedInt32Array([999]), 0, 0.0) or gate.allows_step(start, next):
        _fail("unknown route failed closed incorrectly")
        return
    var outbound: CivicLaneData = graph.get_lane(4)
    var ordinary_start: Vector3 = _point(outbound, 12.0)
    var ordinary_next: Vector3 = _point(outbound, 12.5)
    if not gate.set_route_context(PackedInt32Array([4]), 0, 12.0) or not gate.allows_step(ordinary_start, ordinary_next):
        _fail("non-junction travel permanently blocked")
        return
    gate.clear_context()
    if gate.allows_step(ordinary_start, ordinary_next):
        _fail("cleared context still permitted movement")
        return
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_TRF_002_PERMISSION_PASS")
    quit(0)

func _point(lane: CivicLaneData, distance: float) -> Vector3:
    var remaining: float = distance
    for i in range(1, lane.centerline.size()):
        var from: Vector3 = lane.centerline[i - 1]
        var to: Vector3 = lane.centerline[i]
        var length: float = from.distance_to(to)
        if remaining <= length:
            return from.lerp(to, clampf(remaining / maxf(length, 0.0001), 0.0, 1.0))
        remaining -= length
    return lane.centerline[-1]

func _car(route: PackedInt32Array, distance: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.route = route
    car.current_route_index = 0
    car.lane_distance_m = distance
    car.active = true
    return car

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
