extends SceneTree
## TRAFFIC-FIX-11B — An authorized tow gets a finite central-entry
## clearance opportunity without running a red light or pushing any NPC
## across the stopline. Cars already committed must still finish.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Priority = preload("res://scripts/traffic/central_intersection_priority.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 3122, true):
        _fail("road graph configure failed")
        return
    var signals := Signals.new()
    signals.enable_single_approach_mode()
    var reservations := Reservations.new()
    spawner.configure_intersection(signals, reservations)
    var lanes: Array[CivicLaneData] = []
    for lane_id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(lane_id)
        if Priority.is_inbound(lane):
            lanes.append(lane)
    if lanes.size() < 4:
        _fail("missing central inbound lanes")
        return
    var north: CivicLaneData = null
    var west: CivicLaneData = null
    for lane in lanes:
        if Priority.approach(lane) == "N" and north == null:
            north = lane
        if Priority.approach(lane) == "W" and west == null:
            west = lane
    if north == null or west == null:
        _fail("central N/W lanes missing")
        return
    var service := _car(west, west.length_m() - 5.0)
    var entering := _car(north, north.length_m() - 7.0)
    spawner.register_road_user(service)
    if spawner.central_service_priority_active():
        _fail("unactivated service had priority")
        return
    if bool(spawner.apply_stop_line_observation(entering, {"detected": false}).get("detected", true)):
        _fail("north car could not normally use initial north green")
        return
    spawner.set_central_service_priority(service)
    if not spawner.central_service_priority_active():
        _fail("municipal priority not active")
        return
    if not bool(spawner.apply_stop_line_observation(entering, {"detected": false}).get("detected", false)):
        _fail("new car entered central junction despite active service")
        return
    entering.lane_distance_m = north.length_m() - 3.0
    if bool(spawner.apply_stop_line_observation(entering, {"detected": false}).get("detected", true)):
        _fail("already-committed car was frozen inside the junction")
        return
    entering.active = false
    var service_result: Dictionary = spawner.municipal_service_observation(service)
    if not bool(service_result.get("detected", false)) or spawner.municipal_service_hold_reason(service) != "red_signal":
        _fail("service bypassed its own red")
        return
    signals.advance_fixed(51.0)
    if signals.aspect_for_approach("W") != "green":
        _fail("west green test fixture invalid")
        return
    if bool(spawner.municipal_service_observation(service).get("detected", true)):
        _fail("service not released on its clear green")
        return
    var person_id: int = 10001
    if not bool(reservations.request(person_id,
            PackedStringArray(["pedestrian_crossing_ew"]), 0, 200).get("granted", false)):
        _fail("pedestrian reservation failed")
        return
    if not reservations.occupy(person_id, "pedestrian_crossing_ew"):
        _fail("pedestrian crossing occupancy failed")
        return
    if not bool(spawner.municipal_service_observation(service).get("detected", false)):
        _fail("service ignored protected pedestrian crossing")
        return
    reservations.release(person_id, "pedestrian_crossing_ew")
    reservations.cancel(person_id)
    spawner.clear_central_service_priority(service)
    if spawner.central_service_priority_active():
        _fail("priority persisted beyond service completion")
        return
    signals.reset()
    entering.active = true
    entering.lane_distance_m = north.length_m() - 7.0
    if bool(spawner.apply_stop_line_observation(entering, {"detected": false}).get("detected", true)):
        _fail("normal traffic did not resume after service cleared")
        return
    spawner.set_central_service_priority(service)
    spawner.configure(graph, 3122, true)
    if spawner.central_service_priority_active():
        _fail("temporary municipal priority leaked into new generation")
        return
    spawner.unregister_road_user(service)
    service.free()
    entering.free()
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_11B_MUNICIPAL_PRIORITY_PASS")
    quit(0)

func _car(lane: CivicLaneData, progress: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.route = PackedInt32Array([lane.lane_id])
    car.current_route_index = 0
    car.lane_distance_m = progress
    car.active = true
    return car

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
