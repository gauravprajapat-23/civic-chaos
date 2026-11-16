extends SceneTree
## TRAFFIC-FIX-06: two pedestrian zones protect different approaches.
## The nonconflicting vehicle axis must not be held through its whole
## green simply because someone is walking parallel to that axis.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner: CivicTrafficSpawner = Spawner.new()
    if not spawner.configure(graph, 151, true):
        _fail("city graph configuration failed")
        return
    var signals := Signals.new(4.0, 2.0, 1.0)
    var reservations := Reservations.new()
    spawner.configure_intersection(signals, reservations)
    var ns: CivicLaneData = null
    var ew: CivicLaneData = null
    for lane_id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(lane_id)
        var approach: String = Spawner.signal_approach_for_lane(lane, true)
        if approach == "N" and ns == null:
            ns = lane
        if approach == "W" and ew == null:
            ew = lane
    if ns == null or ew == null:
        _fail("central traffic approaches missing")
        return
    var ns_car := CivicVehicleAgent.new()
    ns_car.active = true
    ns_car.route = PackedInt32Array([ns.lane_id])
    ns_car.lane_distance_m = ns.length_m() - 7.0
    var ew_car := CivicVehicleAgent.new()
    ew_car.active = true
    ew_car.route = PackedInt32Array([ew.lane_id])
    ew_car.lane_distance_m = ew.length_m() - 7.0
    var empty: Dictionary = {"detected": false}
    if Spawner.crossing_conflict_zone("N") != "pedestrian_crossing_ns" or Spawner.crossing_conflict_zone("W") != "pedestrian_crossing_ew":
        _fail("conflicting pedestrian zones assigned to wrong vehicle axes")
        return
    # NS_GREEN: an east/west-conflicting walker may traverse in parallel
    # with NS vehicles, but cannot enter during EW_GREEN.
    if not _occupy(reservations, 10001, "pedestrian_crossing_ew"):
        _fail("pedestrian EW conflict setup failed")
        return
    if Spawner.crossing_blocks_approach(reservations, "N") or not Spawner.crossing_blocks_approach(reservations, "W"):
        _fail("opposite-axis crossing incorrectly blocks both signals")
        return
    if bool(spawner.apply_stop_line_observation(ns_car, empty).get("detected", false)):
        _fail("parallel pedestrian froze NS green")
        return
    if not bool(spawner.apply_stop_line_observation(ew_car, empty).get("detected", false)):
        _fail("red EW approach not stopped")
        return
    if bool(spawner.municipal_service_observation(ns_car).get("detected", false)):
        _fail("municipal service halted by parallel walking")
        return
    reservations.release(10001, "pedestrian_crossing_ew")
    reservations.cancel(10001)
    if not _occupy(reservations, 10002, "pedestrian_crossing_ns"):
        _fail("pedestrian NS conflict setup failed")
        return
    if not bool(spawner.apply_stop_line_observation(ns_car, empty).get("detected", false)):
        _fail("NS green ignored a conflicting occupied crosswalk")
        return
    if spawner.municipal_service_hold_reason(ns_car) != "pedestrian_crossing":
        _fail("tow not held by actual conflicting pedestrian")
        return
    reservations.release(10002, "pedestrian_crossing_ns")
    reservations.cancel(10002)
    if bool(spawner.apply_stop_line_observation(ns_car, empty).get("detected", false)):
        _fail("NS green remained blocked after actual exit")
        return

    signals.advance_fixed(7.0)
    if signals.aspect_for_approach("W") != "green":
        _fail("fixture signal did not switch to EW green")
        return
    if not _occupy(reservations, 10003, "pedestrian_crossing_ns"):
        _fail("NS conflict fixture unavailable")
        return
    if bool(spawner.apply_stop_line_observation(ew_car, empty).get("detected", false)):
        _fail("parallel pedestrian froze EW green")
        return
    if spawner.municipal_service_hold_reason(ew_car) != "":
        _fail("EW tow held on green by nonconflicting pedestrian")
        return
    reservations.release(10003, "pedestrian_crossing_ns")
    reservations.cancel(10003)
    if not _occupy(reservations, 10004, "pedestrian_crossing_ew"):
        _fail("EW conflict fixture unavailable")
        return
    if not bool(spawner.apply_stop_line_observation(ew_car, empty).get("detected", false)):
        _fail("EW green ignored physically occupied conflicting crossing")
        return
    if spawner.municipal_service_hold_reason(ew_car) != "pedestrian_crossing":
        _fail("EW tow ignored real occupied crossing")
        return
    reservations.release(10004, "pedestrian_crossing_ew")
    reservations.cancel(10004)
    if bool(spawner.apply_stop_line_observation(ew_car, empty).get("detected", false)) or spawner.municipal_service_hold_reason(ew_car) != "":
        _fail("EW green did not release after crossing cleared")
        return
    ns_car.free()
    ew_car.free()
    spawner.free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_06_AXIS_CROSSING_RELEASE_PASS")
    quit(0)

func _occupy(reservations: CivicIntersectionReservations, id: int, zone: String) -> bool:
    var request: Dictionary = reservations.request(id, PackedStringArray([zone]), reservations.current_tick, reservations.current_tick + 100)
    return bool(request.get("granted", false)) and reservations.occupy(id, zone)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
