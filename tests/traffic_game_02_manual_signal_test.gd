extends SceneTree
## TRAFFIC-GAME-02: manual traffic control cannot skip minimum green,
## amber, all-red, pedestrian occupancy or occupied central junction.
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const ControlPolicy = preload("res://scripts/civic/traffic_marshal_control.gd")
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var signals := Signals.new(12.0, 3.0, 2.0)
    var reservations := Reservations.new()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(Builder.make_city_graph(), 123, true):
        _fail("city route graph not configured")
        return
    spawner.configure_intersection(signals, reservations)
    var mission_cars: Array[CivicVehicleAgent] = []
    if ControlPolicy.request_axis("EW", signals, reservations, spawner, mission_cars).get("reason") != "minimum_green":
        _fail("immediate switch skipped minimum green interval")
        return
    if ControlPolicy.request_axis("NS", signals, reservations, spawner, mission_cars).get("reason") != "already_green":
        _fail("current green axis incorrectly accepted")
        return
    if bool(ControlPolicy.request_axis("INVALID", signals, reservations, spawner, mission_cars).get("accepted", true)):
        _fail("unknown axis accepted")
        return
    signals.advance_fixed(4.1)
    var pedestrian: int = 730
    var zone: String = "pedestrian_crossing_ew"
    var granted: Dictionary = reservations.request(pedestrian, PackedStringArray([zone]), 0, 60)
    if not bool(granted.get("granted", false)) or not reservations.occupy(pedestrian, zone):
        _fail("pedestrian fixture was not occupied")
        return
    if ControlPolicy.request_axis("EW", signals, reservations, spawner, mission_cars).get("reason") != "pedestrian_in_crossing":
        _fail("controller ignored real pedestrian crossing")
        return
    reservations.release(pedestrian, zone)
    reservations.cancel(pedestrian)
    var graph: CivicRoadGraph = spawner.road_graph
    var entering: CivicLaneData = null
    for lane_id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(lane_id)
        if CivicCentralIntersectionPriority.is_inbound(lane):
            entering = lane
            break
    if entering == null:
        _fail("no inbound central lane")
        return
    var car := CarScene.instantiate() as CivicVehicleAgent
    root.add_child(car)
    car.active = true
    car.route = PackedInt32Array([entering.lane_id])
    car.current_route_index = 0
    car.lane_distance_m = entering.length_m() - 3.0
    spawner.active_vehicles.append(car)
    if ControlPolicy.request_axis("EW", signals, reservations, spawner, mission_cars).get("reason") != "vehicle_in_junction":
        _fail("manual request ignored live vehicle in junction")
        return
    spawner.active_vehicles.clear()
    mission_cars.append(car)
    if ControlPolicy.request_axis("EW", signals, reservations, spawner, mission_cars).get("reason") != "mission_vehicle_in_junction":
        _fail("manual request ignored scripted mission car in junction")
        return
    mission_cars.clear()
    car.active = false
    car.queue_free()
    var accepted: Dictionary = ControlPolicy.request_axis("EW", signals, reservations, spawner, mission_cars)
    if not bool(accepted.get("accepted", false)):
        _fail("safe request was rejected: " + str(accepted))
        return
    if signals.aspect_for_approach("E") != "red" or signals.aspect_for_approach("N") != "green":
        _fail("request illegally switched signal instantly")
        return
    signals.advance_fixed(0.81)
    if signals.phase_name() != "NS_AMBER" or signals.aspect_for_approach("E") != "red":
        _fail("manual request bypassed amber")
        return
    signals.advance_fixed(3.0)
    if signals.phase_name() != "ALL_RED_NS" or signals.aspect_for_approach("N") != "red" or signals.aspect_for_approach("E") != "red":
        _fail("manual request bypassed all-red")
        return
    signals.advance_fixed(2.0)
    if signals.phase_name() != "EW_GREEN" or signals.aspect_for_approach("E") != "green" or signals.aspect_for_approach("N") != "red":
        _fail("manual request failed to reach only the requested axis")
        return
    if signals.has_conflicting_green():
        _fail("perpendicular conflict became green")
        return
    var snapshot: Dictionary = signals.snapshot()
    var restored := Signals.new(12.0, 3.0, 2.0)
    if not restored.restore(snapshot) or restored.phase_name() != signals.phase_name():
        _fail("manual phase rejected by unchanged checkpoint schema")
        return
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_GAME_02_MANUAL_SIGNAL_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
