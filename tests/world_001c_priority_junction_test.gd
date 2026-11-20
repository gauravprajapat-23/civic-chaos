extends SceneTree
## WORLD-001C: only the pilot T has yield priority; the city still
## enforces occupancy, exit spillback, and independent outer signals.
const Network = preload("res://scripts/world/city_network_definition.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Local = preload("res://scripts/traffic/junction_priority_rules.gd")
const Outer = preload("res://scripts/traffic/outer_intersection_priority.gd")
const Lights = preload("res://scripts/traffic/outer_traffic_lights.gd")
var failures: int = 0

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-001C: " + message)

func _car(lane: CivicLaneData, distance: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.active = true
    car.route = PackedInt32Array([lane.lane_id])
    car.current_route_index = 0
    car.lane_distance_m = distance
    return car

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var node := Vector3(-120, 0, -46)
    _check(Local.is_priority_t(node), "pilot T is not classified as a give-way junction")
    _check(not Local.is_priority_t(Vector3(0, 0, 0)),
        "center signal lost authority")
    _check(not Local.is_priority_t(Vector3(46, 0, 46)),
        "unrelated outer intersection was unexpectedly converted")
    _check(not Local.is_priority_t(Vector3(77, 0, 88)),
        "unmapped road position accepted as T junction")
    var total_t: int = 0
    for item in Network.nodes():
        if item["junction_type"] == Network.PRIORITY_T:
            total_t += 1
    _check(total_t == 1, "more than the one verified T junction was converted")

    var graph: CivicRoadGraph = Builder.make_city_graph()
    _check(graph.validate().is_empty(), "existing directed city graph invalid")
    var through: CivicLaneData = graph.get_lane(102) # south to west perimeter T
    var branch: CivicLaneData = graph.get_lane(105) # east branch into west perimeter T
    _check(through != null and branch != null, "legacy T approaches missing")
    if through == null or branch == null:
        quit(1)
        return
    _check(Outer.junction_for_lane(through).distance_to(node) < 0.05 and
        Outer.junction_for_lane(branch).distance_to(node) < 0.05,
        "wrong junction selected for yield rule")
    _check(Local.approach_rank(through) < Local.approach_rank(branch),
        "through road did not outrank side street")

    var through_car: CivicVehicleAgent = _car(through, through.length_m() - 6.0)
    var branch_car: CivicVehicleAgent = _car(branch, branch.length_m() - 6.0)
    var fleet: Array[CivicVehicleAgent] = [through_car, branch_car]
    for tick in [0, 161, 481, 639]:
        var winner: Dictionary = Outer.disposition(through_car, graph, fleet, tick)
        var loser: Dictionary = Outer.disposition(branch_car, graph, fleet, tick)
        _check(winner.get("controlled", false) and not winner.get("yield", true),
            "through vehicle was incorrectly held at tick %d" % tick)
        _check(loser.get("yield", false) and loser.get("reason", "") == "priority_t_yield",
            "side approach was not safely held at tick %d" % tick)

    # When the collector is empty, the side street may cross WITHOUT an
    # artificial four-phase signal. This avoids permanent T-junction queues.
    through_car.active = false
    var side_release: Dictionary = Outer.disposition(branch_car, graph, fleet, 0)
    _check(not side_release.get("yield", true),
        "side street never releases without through traffic")

    # An already committed vehicle always retains its conflict zone
    # ownership, independently of a red phase or approach rank.
    through_car.active = true
    through_car.lane_distance_m = through.length_m() - 2.0
    var occupied: Dictionary = Outer.disposition(branch_car, graph, fleet, 0)
    _check(occupied.get("yield", false) and occupied.get("reason", "") == "zone_occupied",
        "committed collector vehicle was ignored")
    through_car.active = false

    # An occupied outgoing lane is a hard block even with no competing car.
    branch_car.route = PackedInt32Array([105, 106])
    var outgoing: CivicLaneData = graph.get_lane(106)
    var downstream: CivicVehicleAgent = _car(outgoing, 1.0)
    fleet.append(downstream)
    var spillback: Dictionary = Outer.disposition(branch_car, graph, fleet, 0)
    _check(spillback.get("yield", false) and spillback.get("reason", "") == "outbound_blocked",
        "T junction permitted downstream gridlock")

    # Other outer junctions must still honor their old timed red phases.
    var unaffected: CivicLaneData = graph.get_lane(100)
    var other: CivicVehicleAgent = _car(unaffected, unaffected.length_m() - 6.0)
    var normal: Dictionary = Outer.disposition(other, graph, [other], 160)
    var must_hold: bool = Outer.aspect(Outer.approach_for_lane(unaffected), 160) != "green"
    _check(bool(normal.get("yield", false)) == must_hold,
        "existing signalized outer approach behavior changed")

    var lamps: CivicOuterTrafficLights = Lights.new()
    root.add_child(lamps)
    await process_frame
    _check(lamps.head_count() == 92,
        "removed outer lights beyond the four on the single priority T")
    _check(lamps.displayed_tick == 0,
        "outer signal presentation failed to initialize")
    lamps.queue_free()
    through_car.free()
    branch_car.free()
    downstream.free()
    other.free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_001C_PRIORITY_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_001C_PRIORITY_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
