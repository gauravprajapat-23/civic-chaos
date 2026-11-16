extends SceneTree
## TRAFFIC-FIX-11D: after authorized tow removal, queued physical
## mission followers get a bounded green-phase discharge window.
## Other entrants stop before the junction, but are free after the
## followers pass or the window expires. Never override red/pedestrians.
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
    if not spawner.configure(graph, 911, true):
        _fail("city graph setup failed")
        return
    var signals := Signals.new()
    signals.enable_single_approach_mode()
    var reservation := Reservations.new()
    spawner.configure_intersection(signals, reservation)
    var west: CivicLaneData = null
    var north: CivicLaneData = null
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if Priority.is_inbound(lane) and Priority.approach(lane) == "W":
            west = lane
        if Priority.is_inbound(lane) and Priority.approach(lane) == "N":
            north = lane
    if west == null or north == null:
        _fail("incoming lanes absent")
        return
    var mission := _car(west, west.length_m() - 8.0)
    var background := _car(north, north.length_m() - 8.0)
    spawner.register_road_user(mission)
    var followers: Array[CivicVehicleAgent] = [mission]
    if spawner.start_central_recovery([], 5) or spawner.start_central_recovery(followers, 3000):
        _fail("accepted invalid recovery window")
        return
    if not spawner.start_central_recovery(followers, 250):
        _fail("real follower could not reserve discharge")
        return
    if not spawner.central_recovery_active() or not spawner.central_recovery_allows(mission):
        _fail("real follower not authorized by recovery gate")
        return
    if not bool(spawner.apply_stop_line_observation(background, {"detected": false}).get("detected", false)):
        _fail("ordinary new traffic admitted ahead of actual recovery")
        return
    if not bool(spawner.apply_stop_line_observation(mission, {"detected": false}).get("detected", false)):
        _fail("mission follower ran its red signal")
        return
    signals.advance_fixed(51.0)
    if signals.aspect_for_approach("W") != "green":
        _fail("fixture did not reach west green")
        return
    if bool(spawner.apply_stop_line_observation(mission, {"detected": false}).get("detected", true)):
        _fail("genuine follower remains stopped at clear west green")
        return
    var id: int = 109
    var zone: String = "pedestrian_crossing_ew"
    if not bool(reservation.request(id, PackedStringArray([zone]), 0, 100).get("granted", false)) or not reservation.occupy(id, zone):
        _fail("crosswalk setup failed")
        return
    if not bool(spawner.apply_stop_line_observation(mission, {"detected": false}).get("detected", false)):
        _fail("recovery priority bypassed pedestrian reservation")
        return
    reservation.release(id, zone)
    reservation.cancel(id)
    mission.current_route_index = 1
    if spawner.central_recovery_active():
        _fail("recovery gate did not release when mission car passed center")
        return
    signals.reset()
    if bool(spawner.apply_stop_line_observation(background, {"detected": false}).get("detected", true)):
        _fail("normal north traffic did not resume after follower cleared")
        return
    mission.current_route_index = 0
    spawner.current_tick = 251
    if spawner.central_recovery_active():
        _fail("bounded recovery did not expire")
        return
    if bool(spawner.apply_stop_line_observation(background, {"detected": false}).get("detected", true)):
        _fail("stale gate blocked traffic after expiry")
        return
    spawner.clear_central_recovery()
    spawner.unregister_road_user(mission)
    mission.free()
    background.free()
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_11D_FOLLOWER_RELEASE_PASS")
    quit(0)

func _car(lane: CivicLaneData, distance: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.active = true
    car.route = PackedInt32Array([lane.lane_id, 0])
    car.current_route_index = 0
    car.lane_distance_m = distance
    return car

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
