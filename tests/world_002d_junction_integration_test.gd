extends SceneTree
## WORLD-002D: test the *new* non-grid intersection is actually controlled,
## preserves tick-deterministic right-of-way and lets existing routes survive.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Priority = preload("res://scripts/traffic/outer_intersection_priority.gd")
const Connector = preload("res://scripts/world/world_002_neighborhood_connector.gd")
const LocalRules = preload("res://scripts/traffic/junction_priority_rules.gd")
const Route = preload("res://scripts/ui/civic_map_routes.gd")
var failures: int = 0

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-002D: " + message)

func _car(lane: CivicLaneData, gap: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.active = true
    car.route = PackedInt32Array([lane.lane_id])
    car.current_route_index = 0
    car.lane_distance_m = lane.length_m() - gap
    car.minimum_gap_m = 2.0
    return car

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    _check(graph.validate().is_empty() and graph.lane_count() == 84,
        "new network malformed or lane count changed")
    var inbound_a: CivicLaneData = graph.get_lane(1000)
    var inbound_b: CivicLaneData = graph.get_lane(1003)
    _check(inbound_a != null and inbound_b != null, "new junction lacks incoming roads")
    if inbound_a == null or inbound_b == null:
        quit(1)
        return
    _check(Priority.is_controlled(inbound_a) and Priority.is_controlled(inbound_b),
        "new non-grid junction is not protected by outer priority policy")
    _check(Priority.junction_for_lane(inbound_a).distance_to(Connector.JUNCTION) < 0.05,
        "outer junction snapped to wrong road node")
    _check(LocalRules.classification(Connector.JUNCTION) == "legacy_outer_controlled",
        "interior bend classification must use deterministic outer conflict gate")

    var car_a := _car(inbound_a, 7.0)
    var car_b := _car(inbound_b, 7.0)
    var cars: Array[CivicVehicleAgent] = [car_a, car_b]
    # At most one approach may be green, including all-red clearance.
    var allowed: int = 0
    for tick in range(Priority.PERIOD_TICKS):
        var a: Dictionary = Priority.disposition(car_a, graph, cars, tick)
        var b: Dictionary = Priority.disposition(car_b, graph, cars, tick)
        _check(bool(a.get("controlled", false)) and bool(b.get("controlled", false)),
            "new node is not controlled for a full timing cycle")
        var admitting: int = int(not bool(a.get("yield", true))) + int(not bool(b.get("yield", true)))
        if admitting > 1:
            _check(false, "two conflicting vehicles got simultaneous access")
            break
        allowed += admitting
    _check(allowed > 0, "both approaches starved for an entire conflict cycle")
    var replay_a: Dictionary = Priority.disposition(car_a, graph, cars, 1)
    Priority.disposition(car_a, graph, cars, 240)
    _check(Priority.disposition(car_a, graph, cars, 1) == replay_a,
        "priority changes with unsaved state after tick rewind")
    # A vehicle already inside the junction must block a competing
    # approach even if that other approach has a nominal green phase.
    car_a.lane_distance_m = inbound_a.length_m() - 3.0
    _check(Priority.occupies(car_a, graph, Connector.JUNCTION),
        "committed car not counted as physical conflict occupancy")
    var competing: Dictionary = Priority.disposition(car_b, graph, cars, 320)
    _check(bool(competing.get("yield", false)),
        "occupied junction allowed another car to enter")
    car_a.free()
    car_b.free()

    var road_route: Dictionary = Route.plan(graph, Connector.WEST, Connector.EAST)
    _check(bool(road_route.get("ok", false)),
        "player GPS path cannot navigate between connector endpoints")
    var path: PackedVector3Array = road_route.get("points", PackedVector3Array())
    _check(path.size() >= 2, "GPS route returned empty geometry")
    var old_route: Dictionary = Route.plan(graph,
        Vector3(-120, 0, -120), Vector3(0, 0, 0))
    _check(bool(old_route.get("ok", false)),
        "legacy city GPS route disconnected by new road")
    _check(graph.get_lane(102) != null and graph.get_lane(179) != null,
        "historic checkpoint IDs are no longer available")

    if failures == 0:
        print("CIVIC_CHAOS_WORLD_002D_JUNCTION_INTEGRATION_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_002D_JUNCTION_INTEGRATION_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
