extends SceneTree
## Expanded-city signals must map inbound geometry, not legacy junction IDs.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const OuterPriority = preload("res://scripts/traffic/outer_intersection_priority.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner: CivicTrafficSpawner = Spawner.new()
    if not spawner.configure(graph, 312, true):
        _fail("city spawner configuration failed")
        return
    var signals := Signals.new(4.0, 2.0, 1.0)
    spawner.configure_intersection(signals, null)
    var north: CivicLaneData
    var east: CivicLaneData
    var outer: CivicLaneData
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        var approach: String = Spawner.signal_approach_for_lane(lane, true)
        if approach == "N" and north == null:
            north = lane
        if approach == "E" and east == null:
            east = lane
        if approach == "" and outer == null:
            outer = lane
    if north == null or east == null or outer == null:
        _fail("expected north/east center lanes and an unsignaled outer lane")
        return
    if north.lane_id < 100 or east.lane_id < 100:
        _fail("test did not exercise expanded-city lane IDs")
        return
    var north_car := CivicVehicleAgent.new()
    north_car.route = PackedInt32Array([north.lane_id])
    north_car.lane_distance_m = north.length_m() - 7.0
    var east_car := CivicVehicleAgent.new()
    east_car.route = PackedInt32Array([east.lane_id])
    east_car.lane_distance_m = east.length_m() - 7.0
    var outer_car := CivicVehicleAgent.new()
    outer_car.route = PackedInt32Array([outer.lane_id])
    outer_car.lane_distance_m = outer.length_m() - 7.0
    outer_car.active = true
    spawner.current_tick = 1
    var empty := {"detected": false}
    if spawner.apply_stop_line_observation(north_car, empty).get("detected", false):
        _fail("north green wrongly stopped")
        return
    if not spawner.apply_stop_line_observation(east_car, empty).get("detected", false):
        _fail("east red failed to stop")
        return
    # Outer city nodes have their OWN fixed-tick right-of-way, independent
    # of the central signal. It is no longer correct to expect no stop.
    var outer_red: bool = OuterPriority.aspect(OuterPriority.axis_for_lane(outer), 1) != "green"
    if bool(spawner.apply_stop_line_observation(outer_car, empty).get("detected", false)) != outer_red:
        _fail("outer fixed-tick priority does not match its approach signal")
        return
    signals.advance_fixed(7.0)
    if not spawner.apply_stop_line_observation(north_car, empty).get("detected", false):
        _fail("north red failed to stop")
        return
    if spawner.apply_stop_line_observation(east_car, empty).get("detected", false):
        _fail("east green failed to release")
        return
    north_car.free()
    east_car.free()
    outer_car.free()
    spawner.free()
    print("CIVIC_CHAOS_CITY_SIGNAL_STOP_LINE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
