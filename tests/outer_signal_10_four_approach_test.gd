extends SceneTree
## OUTER-SIGNAL-10: all 24 noncentral junctions use exclusive
## North/East/South/West green permissions, visible heads and deterministic
## F5/F9 tick replay. Central junction remains a separate controller.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Policy = preload("res://scripts/traffic/outer_intersection_priority.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Lights = preload("res://scripts/traffic/outer_traffic_lights.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    if graph == null or not graph.validate().is_empty():
        _fail("city graph invalid")
        return
    var node: Vector3 = Vector3(46.0, 0, 46.0)
    var approaches: Dictionary = {}
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if Policy.junction_for_lane(lane).distance_to(node) <= 0.05:
            approaches[Policy.approach_for_lane(lane)] = lane
    for direction in ["N", "E", "S", "W"]:
        if not approaches.has(direction):
            _fail("missing outer " + direction + " route")
            return
    var lights := Lights.new() as CivicOuterTrafficLights
    root.add_child(lights)
    if lights.head_count() != 96:
        _fail("each of the 24 outer intersections requires four heads")
        return
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 123, true):
        _fail("traffic spawner rejected outer graph")
        return
    var live: Array[CivicVehicleAgent] = []
    for direction in ["N", "E", "S", "W"]:
        var lane: CivicLaneData = approaches[direction]
        var car := CivicVehicleAgent.new()
        car.active = true
        car.route = PackedInt32Array([lane.lane_id])
        car.current_route_index = 0
        car.lane_distance_m = lane.length_m() - 7.0
        live.append(car)
    var cycle: Array[String] = ["N", "E", "S", "W"]
    for turn in range(4):
        var phase_tick: int = turn * (Policy.GREEN_TICKS + Policy.CLEARANCE_TICKS) + 1
        lights.sync_tick(phase_tick)
        spawner.current_tick = phase_tick
        var allowed: String = cycle[turn]
        var num_green: int = 0
        for index in range(4):
            var direction: String = cycle[index]
            var logical: bool = Policy.aspect(direction, phase_tick) == "green"
            var shown: bool = lights.displayed_aspect(direction) == "green"
            if logical != shown:
                _fail("outer rendered green disagrees with right-of-way")
                return
            num_green += int(logical)
            var held: bool = bool(Policy.disposition(live[index], graph, live, phase_tick).get("yield", true))
            if held != (direction != allowed):
                _fail("outer car %s did not follow exclusive %s green" % [direction, allowed])
                return
        if num_green != 1:
            _fail("more or fewer than one outer green at turn %d" % turn)
            return
        var red_tick: int = (turn + 1) * (Policy.GREEN_TICKS + Policy.CLEARANCE_TICKS) - 1
        lights.sync_tick(red_tick)
        for direction in cycle:
            if lights.displayed_aspect(direction) != "red":
                _fail("outer clearance did not stop all four approaches")
                return
        lights.sync_tick(phase_tick)
        if lights.displayed_tick != phase_tick or lights.displayed_aspect(allowed) != "green":
            _fail("head state failed deterministic restore at saved tick")
            return
    if Policy.aspect("N", Policy.PERIOD_TICKS) != "green":
        _fail("four-turn cycle does not repeat at saved clock boundary")
        return
    for car in live:
        car.free()
    spawner.queue_free()
    lights.queue_free()
    print("CIVIC_CHAOS_OUTER_SIGNAL_10_FOUR_APPROACH_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
