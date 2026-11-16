extends SceneTree
## TRAFFIC-FIX-08: central exit capacity stops new junction entry and
## does not let a blocked contender monopolize an otherwise open green.
## It preserves committed-vehicle occupancy, red phases and checkpoint
## determinism without moving any car or reducing collision protections.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Priority = preload("res://scripts/traffic/central_intersection_priority.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var first := _car(PackedInt32Array([1, 4]), graph.get_lane(1).length_m() - 5.8)
    var alternative := _car(PackedInt32Array([5, 8]), graph.get_lane(5).length_m() - 6.0)
    var downstream := _car(PackedInt32Array([4]), Priority.OUTBOUND_QUEUE_CLEARANCE_M - 0.5)
    var cars: Array[CivicVehicleAgent] = [first, alternative, downstream]
    var first_gap: float = graph.get_lane(1).length_m() - 5.0 - first.lane_distance_m
    var alt_gap: float = graph.get_lane(5).length_m() - 5.0 - alternative.lane_distance_m

    if Priority.exit_available(first, cars):
        _fail("outbound queue was not detected")
        return
    var blocked: Dictionary = Priority.disposition(first, graph, cars, first_gap)
    if not bool(blocked.get("yield", false)) or blocked.get("reason") != "central_outbound_blocked":
        _fail("first car can enter junction with no safe exit")
        return
    var alt: Dictionary = Priority.disposition(alternative, graph, cars, alt_gap)
    if bool(alt.get("yield", true)):
        _fail("blocked approach starved the open alternative")
        return

    downstream.lane_distance_m = Priority.OUTBOUND_QUEUE_CLEARANCE_M + 0.5
    if not Priority.exit_available(first, cars):
        _fail("exit remained blocked after physical downstream clearance")
        return
    var priority: Dictionary = Priority.disposition(first, graph, cars, first_gap)
    if bool(priority.get("yield", true)):
        _fail("first approach did not release after downstream queue moved")
        return
    if not bool(Priority.disposition(alternative, graph, cars, alt_gap).get("yield", false)):
        _fail("alternative was also granted into an occupied conflict")
        return

    first.lane_distance_m = graph.get_lane(1).length_m() - 3.0
    if not Priority.occupies(first, graph):
        _fail("committed central entrant is not recognized")
        return
    if not bool(Priority.disposition(alternative, graph, cars, alt_gap).get("yield", false)):
        _fail("already-entered vehicle was no longer protected")
        return

    first.active = false
    alternative.active = false
    downstream.active = false
    first.free()
    alternative.free()
    downstream.free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_08_CENTRAL_SPILLBACK_PASS")
    quit(0)

func _car(route: PackedInt32Array, distance: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.route = route
    car.current_route_index = 0
    car.lane_distance_m = distance
    car.active = true
    return car

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
