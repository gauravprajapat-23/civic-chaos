extends SceneTree

const Builder = preload("res://scripts/world/junction_builder.gd")
const Router = preload("res://scripts/traffic/lane_router.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Incidents = preload("res://scripts/civic/incident_manager.gd")
const Scenario = preload("res://scripts/civic/wrong_way_scenario.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph := Builder.make_test_graph()
    var slots := Reservations.new()
    var incidents := Incidents.new()
    var scenario := Scenario.new()
    assert(scenario.configure(graph, slots, incidents, 1, 99))
    assert(graph.validate().is_empty())
    assert(not graph.outgoing_legal_lanes(1, 1).has(99))
    var router := Router.new(graph)
    assert(not router.find_route(1, 99, 1)["ok"])
    assert(scenario.enter_violation(5, 1))
    assert(not scenario.enter_violation(6, 1))
    assert(slots.active_reservation_count() == 0)
    for tick in range(2, 7):
        assert(scenario.advance_to(tick, 2))
    assert(scenario.metrics()["queue"] == 10)
    assert(scenario.intervene(7))
    for tick in range(8, 13):
        assert(scenario.advance_to(tick, 2))
    assert(scenario.metrics()["queue"] == 0)
    assert(scenario.resolve(13))
    assert(incidents.incidents[scenario.incident_id]["state"] == "resolved")
    assert(not scenario.enter_violation(-1, 14))
    print("CIVIC_CHAOS_WRONG_WAY_PASS")
    quit(0)
