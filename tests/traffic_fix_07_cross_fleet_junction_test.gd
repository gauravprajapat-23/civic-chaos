extends SceneTree
## TRAFFIC-FIX-07: a mission-owned car is a real physical road occupant.
## Background vehicles must see it at the center, and the mission car
## must see regular vehicles. Neither is duplicated in save/reward counters.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Priority = preload("res://scripts/traffic/central_intersection_priority.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 1337, true):
        _fail("city traffic configure failed")
        return
    var signals := Signals.new(12.0, 3.0, 2.0)
    spawner.configure_intersection(signals, null)
    var inbound: Array[CivicLaneData] = []
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if Priority.is_inbound(lane) and Spawner.signal_approach_for_lane(lane, true) == "N":
            inbound.append(lane)
    if inbound.is_empty():
        _fail("north-bound central approach missing")
        return
    var lane: CivicLaneData = inbound[0]
    var mission := CivicVehicleAgent.new()
    mission.active = true
    mission.route = PackedInt32Array([lane.lane_id])
    mission.current_route_index = 0
    mission.lane_distance_m = lane.length_m() - 3.0
    if not Priority.occupies(mission, graph):
        _fail("mission occupancy fixture not inside protected intersection")
        return
    var regular := CivicVehicleAgent.new()
    regular.active = true
    regular.route = PackedInt32Array([lane.lane_id])
    regular.current_route_index = 0
    regular.lane_distance_m = lane.length_m() - 8.0
    spawner.active_vehicles.append(regular)
    if bool(spawner.apply_stop_line_observation(regular, {"detected": false}).get("detected", false)):
        _fail("unregistered mission vehicle unexpectedly changed spawner priority")
        return
    spawner.register_road_user(mission)
    spawner.register_road_user(mission)
    var all: Array[CivicVehicleAgent] = spawner.traffic_road_users()
    if all.size() != 2 or all[0] != regular or all[1] != mission:
        _fail("mission vehicle registration duplicated or shuffled fleet")
        return
    var held: Dictionary = spawner.apply_stop_line_observation(regular, {"detected": false})
    if not bool(held.get("detected", false)):
        _fail("ordinary car admitted despite mission vehicle inside junction")
        return
    mission.lane_distance_m = lane.length_m() - 8.5
    if bool(spawner.apply_stop_line_observation(regular, {"detected": false}).get("detected", false)):
        _fail("cleared mission vehicle left a phantom junction reservation")
        return
    mission.active = false
    if spawner.traffic_road_users().size() != 1:
        _fail("inactive mission vehicle still occupies shared live fleet")
        return
    mission.active = true
    spawner.unregister_road_user(mission)
    if spawner.traffic_road_users().size() != 1:
        _fail("unregistered mission car still controls traffic")
        return
    if spawner.completed_total != 0 or spawner.spawned_total != 0:
        _fail("external mission vehicles altered city traffic counters")
        return
    spawner.active_vehicles.clear()
    mission.free()
    regular.free()
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_07_CROSS_FLEET_JUNCTION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
