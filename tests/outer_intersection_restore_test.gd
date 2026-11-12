extends SceneTree
## AUD2-MAP-04: an occupied crossing must survive JSON checkpoint rewind.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Priority = preload("res://scripts/traffic/outer_intersection_priority.gd")
const Lights = preload("res://scripts/traffic/outer_traffic_lights.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var node := Vector3(46.0, 0, 46.0)
    var incoming: CivicLaneData
    var cross: CivicLaneData
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if Priority.junction_for_lane(lane).distance_to(node) > 0.05:
            continue
        if Priority.axis_for_lane(lane) == "ns" and incoming == null:
            incoming = lane
        if Priority.axis_for_lane(lane) == "ew" and cross == null:
            cross = lane
    if incoming == null or cross == null:
        _fail("perpendicular crossing unavailable")
        return
    var stage := Node3D.new()
    root.add_child(stage)
    var original := Spawner.new() as CivicTrafficSpawner
    original.spawn_interval_ticks = 100000
    stage.add_child(original)
    if not original.configure(graph, 6262, true):
        _fail("city spawner unavailable")
        return
    var inside := _make_car(original, graph, incoming)
    var waiting := _make_car(original, graph, cross)
    if inside == null or waiting == null:
        _fail("vehicle scene invalid")
        return
    inside.lane_distance_m = incoming.length_m() - 2.5
    inside._place_on_lane()
    waiting.lane_distance_m = cross.length_m() - 9.0
    waiting._place_on_lane()
    original.active_vehicles.append(inside)
    original.active_vehicles.append(waiting)
    # This fixture injects cars instead of using try_spawn(). Preserve the
    # production invariant: each live car must count toward spawned_total.
    original.spawned_total = original.active_vehicles.size()
    original.current_tick = 160
    if not Priority.occupies(inside, graph, node):
        _fail("fixture did not occupy conflict zone")
        return
    var before: Dictionary = Priority.disposition(waiting, graph, original.active_vehicles, 160)
    if before.get("reason") != "zone_occupied":
        _fail("occupied junction did not hold green cross-traffic")
        return
    var saved: Variant = JSON.parse_string(JSON.stringify(original.snapshot()))
    if not original.can_restore(saved):
        _fail("occupied crossing checkpoint invalid after coherent spawn accounting")
        return
    # Keep the strict validator: an injected active fleet without matching
    # spawn history is not an acceptable checkpoint.
    var impossible: Dictionary = (saved as Dictionary).duplicate(true)
    impossible["spawned_total"] = 0
    if original.can_restore(impossible):
        _fail("checkpoint accepted active cars with no spawn history")
        return
    stage.queue_free()
    await physics_frame
    await physics_frame
    var next_stage := Node3D.new()
    root.add_child(next_stage)
    var resumed := Spawner.new() as CivicTrafficSpawner
    resumed.spawn_interval_ticks = 100000
    next_stage.add_child(resumed)
    if not resumed.configure(graph, 6262, true):
        _fail("resumed spawner rejected city graph")
        return
    await physics_frame
    if not resumed.restore(saved):
        _fail("occupied crossing failed JSON restoration")
        return
    if resumed.active_vehicles.size() != 2 or resumed.current_tick != 160:
        _fail("restored car slots or clock changed")
        return
    var restored_inside: CivicVehicleAgent = resumed.active_vehicles[0]
    var restored_waiting: CivicVehicleAgent = resumed.active_vehicles[1]
    var after: Dictionary = Priority.disposition(restored_waiting, graph, resumed.active_vehicles, resumed.current_tick)
    if after != before or not Priority.occupies(restored_inside, graph, node):
        _fail("junction ownership did not replay from saved positions")
        return
    # On the outbound lane, ownership must still protect the crossing.
    restored_inside.current_route_index = 1
    restored_inside.lane_distance_m = 3.0
    restored_inside._place_on_lane()
    if not Priority.occupies(restored_inside, graph, node):
        _fail("restored outbound clearance lost ownership")
        return
    restored_inside.lane_distance_m = Priority.EXIT_CLEARANCE_M + 0.3
    restored_inside._place_on_lane()
    if Priority.occupies(restored_inside, graph, node):
        _fail("crossing ownership remained after clearance")
        return
    if Priority.disposition(restored_waiting, graph, resumed.active_vehicles, 160).get("yield", true):
        _fail("restored waiting car did not receive right of way after clearance")
        return
    var lights := Lights.new() as CivicOuterTrafficLights
    next_stage.add_child(lights)
    if lights.head_count() != 48:
        _fail("outer signal heads missing at city nodes")
        return
    for tick in [0, 119, 120, 159, 160, 279, 280, 319]:
        lights.sync_tick(tick)
        if lights.displayed_aspect("ns") != Priority.aspect("ns", tick) or lights.displayed_aspect("ew") != Priority.aspect("ew", tick):
            _fail("visual lamps diverged from junction priority on tick " + str(tick))
            return
    lights.sync_tick(int((saved as Dictionary)["current_tick"]))
    if lights.displayed_tick != resumed.current_tick or lights.displayed_aspect("ew") != "green":
        _fail("restored clock did not recover visible signal phase")
        return
    next_stage.queue_free()
    print("CIVIC_CHAOS_OUTER_INTERSECTION_RESTORE_PASS")
    quit(0)

func _make_car(spawner: CivicTrafficSpawner, graph: CivicRoadGraph, lane: CivicLaneData) -> CivicVehicleAgent:
    var choices: Array[int] = graph.outgoing_legal_lanes(lane.lane_id, 1)
    if choices.is_empty():
        return null
    var car := VehicleScene.instantiate() as CivicVehicleAgent
    if car == null:
        return null
    car.feedback_enabled = false
    spawner.add_child(car)
    if not car.configure(graph, PackedInt32Array([lane.lane_id, choices[0]]), Profile.new()):
        car.queue_free()
        return null
    return car

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
