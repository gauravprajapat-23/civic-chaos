extends SceneTree
## TRF-003 — diagnostic reason transitions, strict authorization parity,
## deterministic capped snapshots and no-adapter / stale-context denial.
const Telemetry = preload("res://scripts/traffic/responder_hold_telemetry.gd")
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
        _fail("spawner setup")
        return
    var telemetry := Telemetry.new() as CivicResponderHoldTelemetry
    var gate := Adapter.new() as CivicResponderStepPermission
    var inbound: CivicLaneData = graph.get_lane(1)
    var distance: float = inbound.length_m() - 6.5
    var start: Vector3 = _point(inbound, distance)
    var finish: Vector3 = _point(inbound, distance + 0.7)
    if telemetry.evaluate(null, start, finish, 0) or telemetry.snapshot()["reason"] != "no_adapter":
        _fail("missing adapter did not fail closed")
        return
    if not gate.configure(spawner) or telemetry.evaluate(gate, start, finish, 1):
        _fail("unconfigured route permission")
        return
    if telemetry.snapshot()["reason"] != "stale_route_context":
        _fail("missing route reason changed")
        return
    if not gate.set_route_context(PackedInt32Array([1, 4]), 0, distance):
        _fail("legal route setup")
        return
    if telemetry.evaluate(gate, start, finish, 21) or telemetry.snapshot()["reason"] != "missing_signal":
        _fail("missing signal incorrectly permitted")
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
        _fail("green signal setup")
        return
    if not telemetry.evaluate(gate, start, finish, 40) or telemetry.snapshot()["reason"] != "clear":
        _fail("green did not recover from hold")
        return
    signals.advance_fixed(12.0)
    if telemetry.evaluate(gate, start, finish, 41) or telemetry.snapshot()["reason"] != "red_signal":
        _fail("amber reason not red_signal")
        return
    signals.advance_fixed(3.0)
    if telemetry.evaluate(gate, start, finish, 61) or telemetry.snapshot()["reason"] != "red_signal":
        _fail("all-red did not stay held")
        return
    signals.advance_fixed(2.0)
    for i in range(4):
        if signals.aspect_for_approach(approach) == "green":
            break
        signals.advance_fixed(17.0)
    if signals.aspect_for_approach(approach) != "green":
        _fail("return to green")
        return

    var zone: String = Spawner.crossing_conflict_zone(approach)
    if not bool(reservations.request(711, PackedStringArray([zone]), 0, 100).get("granted", false)) or not reservations.occupy(711, zone):
        _fail("pedestrian reservation fixture")
        return
    if telemetry.evaluate(gate, start, finish, 81) or telemetry.snapshot()["reason"] != "pedestrian_crossing":
        _fail("pedestrian reservation reason")
        return
    reservations.release(711, zone)
    reservations.cancel(711)
    if not telemetry.evaluate(gate, start, finish, 82) or telemetry.snapshot()["reason"] != "clear":
        _fail("crossing recovery")
        return

    var downstream := _car(PackedInt32Array([4]), Priority.OUTBOUND_QUEUE_CLEARANCE_M - 0.5)
    spawner.register_road_user(downstream)
    if telemetry.evaluate(gate, start, finish, 83) or telemetry.snapshot()["reason"] != "central_outbound_blocked":
        _fail("blocked exit reason")
        return
    downstream.lane_distance_m = Priority.OUTBOUND_QUEUE_CLEARANCE_M + 0.5
    if not telemetry.evaluate(gate, start, finish, 84) or telemetry.snapshot()["reason"] != "clear":
        _fail("exit recovery")
        return
    downstream.route = PackedInt32Array([1, 4])
    downstream.current_route_index = 0
    downstream.lane_distance_m = inbound.length_m() - 3.0
    if telemetry.evaluate(gate, start, finish, 85) or telemetry.snapshot()["reason"] != "central_zone_occupied":
        _fail("committed central car reason")
        return
    spawner.unregister_road_user(downstream)
    downstream.free()
    if not telemetry.evaluate(gate, start, finish, 86) or telemetry.snapshot()["reason"] != "clear":
        _fail("central occupancy recovery")
        return

    gate.clear_context()
    if telemetry.evaluate(gate, start, finish, 87) or telemetry.snapshot()["reason"] != "stale_route_context":
        _fail("stale context incorrectly permitted")
        return
    if not gate.set_route_context(PackedInt32Array([1, 4]), 0, 0.0) or telemetry.evaluate(gate, start, finish, 88):
        _fail("stale progress incorrectly permitted")
        return
    if telemetry.snapshot()["reason"] != "stale_route_context":
        _fail("stale progress diagnostic reason")
        return
    if not gate.set_route_context(PackedInt32Array([1, 4]), 0, distance):
        _fail("route recovery")
        return
    if telemetry.evaluate(gate, start, start + Vector3(8, 0, 0), 89) or telemetry.snapshot()["reason"] != "invalid_motion":
        _fail("invalid motion incorrectly permitted")
        return

    # Bounded history and deterministic no-allocation cadence; repeat at
    # fixed integer ticks and ensure identical reason sequence.
    for i in range(100):
        telemetry.evaluate(gate, start, finish, 100 + i * Telemetry.SAMPLE_PERIOD_TICKS)
    var saved: Dictionary = telemetry.snapshot()
    if int(saved["sample_count"]) != Telemetry.MAX_SAMPLES or (
            (saved["samples"] as Array).size() != Telemetry.MAX_SAMPLES):
        _fail("unbounded diagnostic sample history")
        return
    if int(saved["observed_steps"]) != 114 or int(saved["denied_steps"]) <= 0:
        _fail("diagnostic counters corrupted")
        return
    var detached: Dictionary = telemetry.snapshot()
    (detached["samples"] as Array).clear()
    if int(telemetry.snapshot()["sample_count"]) != Telemetry.MAX_SAMPLES:
        _fail("snapshot mutated internal telemetry")
        return
    var ordinary_lane: CivicLaneData = graph.get_lane(4)
    var normal_start: Vector3 = _point(ordinary_lane, 12.0)
    var normal_finish: Vector3 = _point(ordinary_lane, 12.5)
    if not gate.set_route_context(PackedInt32Array([4]), 0, 12.0) or (
            not telemetry.evaluate(gate, normal_start, normal_finish, 2200)):
        _fail("noncentral road traversal blocked")
        return
    telemetry.reset()
    if telemetry.snapshot()["sample_count"] != 0:
        _fail("reset did not release history")
        return
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_TRF_003_TELEMETRY_PASS")
    quit(0)

func _car(route: PackedInt32Array, at_distance: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.route = route
    car.current_route_index = 0
    car.lane_distance_m = at_distance
    car.active = true
    return car

func _point(lane: CivicLaneData, at_distance: float) -> Vector3:
    var remaining: float = at_distance
    for i in range(1, lane.centerline.size()):
        var a: Vector3 = lane.centerline[i - 1]
        var b: Vector3 = lane.centerline[i]
        var length: float = a.distance_to(b)
        if remaining <= length:
            return a.lerp(b, clampf(remaining / maxf(length, 0.00001), 0.0, 1.0))
        remaining -= length
    return lane.centerline[-1]

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
