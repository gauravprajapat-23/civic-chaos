extends SceneTree
## The municipal truck is an external mission car, not a fleet slot.
## It must not be permanently outranked by unrelated queued traffic,
## yet a red phase, occupied center, or genuine pedestrian must stop it.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 867, true):
        _fail("city graph setup failed")
        return
    var signals := Signals.new(4.0, 2.0, 1.0)
    var reservations := Reservations.new()
    spawner.configure_intersection(signals, reservations)
    var lane: CivicLaneData = null
    for id in graph.sorted_lane_ids():
        var candidate: CivicLaneData = graph.get_lane(id)
        if candidate.centerline[0].distance_to(Vector3(-46, 0, 0)) < 0.05 and candidate.centerline[candidate.centerline.size()-1].distance_to(Vector3.ZERO) < 0.05:
            lane = candidate
            break
    if lane == null:
        _fail("mission approach lane not found")
        return
    var service := CivicVehicleAgent.new()
    service.active = true
    service.route = PackedInt32Array([lane.lane_id])
    service.current_route_index = 0
    service.lane_distance_m = lane.length_m() - 7.0
    service.minimum_gap_m = 2.0
    var rival := CivicVehicleAgent.new()
    rival.active = true
    rival.route = PackedInt32Array([lane.lane_id])
    rival.current_route_index = 0
    rival.lane_distance_m = lane.length_m() - 5.3
    spawner.active_vehicles.append(rival)
    if not bool(spawner.municipal_service_observation(service).get("detected", true)) or spawner.municipal_service_hold_reason(service) != "red_signal":
        # The approach is west to east and starts as NS-green, so red.
        _fail("red signal was bypassed by service convoy")
        return
    signals.advance_fixed(7.0)
    if bool(spawner.municipal_service_observation(service).get("detected", true)):
        _fail("green convoy remains stuck behind fleet priority contender")
        return
    var pedestrian_id: int = 777
    var zone: String = "pedestrian_crossing_ew"
    var granted: Dictionary = reservations.request(pedestrian_id, PackedStringArray([zone]), 0, 80)
    if not bool(granted.get("granted", false)) or not reservations.occupy(pedestrian_id, zone):
        _fail("pedestrian fixture failed")
        return
    if not bool(spawner.municipal_service_observation(service).get("detected", false)) or spawner.municipal_service_hold_reason(service) != "pedestrian_crossing":
        _fail("crossing reservation was ignored")
        return
    reservations.release(pedestrian_id, zone)
    reservations.cancel(pedestrian_id)
    if bool(spawner.municipal_service_observation(service).get("detected", true)):
        _fail("departed pedestrian remains a phantom blocker")
        return
    rival.lane_distance_m = lane.length_m() - 2.0
    if not bool(spawner.municipal_service_observation(service).get("detected", false)) or spawner.municipal_service_hold_reason(service) != "central_zone_occupied":
        _fail("real occupied intersection was ignored")
        return
    rival.lane_distance_m = lane.length_m() - 8.0
    if bool(spawner.municipal_service_observation(service).get("detected", true)):
        _fail("cleared intersection did not release service")
        return
    # A convoy past the stopline must not be frozen by a subsequent red.
    service.lane_distance_m = lane.length_m() - 3.0
    signals.advance_fixed(4.0)
    if bool(spawner.municipal_service_observation(service).get("detected", true)):
        _fail("convoy already committed to crossing stopped inside junction")
        return
    spawner.active_vehicles.clear()
    rival.free()
    service.free()
    spawner.queue_free()
    print("CIVIC_CHAOS_WRONG_WAY_TOW_SERVICE_PRIORITY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
