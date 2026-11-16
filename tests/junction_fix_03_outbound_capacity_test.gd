extends SceneTree
## JUNCTION-FIX-03 — A green approach may enter only if the outbound
## lane has space beyond the 7 m junction conflict zone. Congested priority
## winners must not starve a clear exit, and no red/occupant is overridden.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Priority = preload("res://scripts/traffic/outer_intersection_priority.gd")
const StopDiag = preload("res://scripts/traffic/traffic_stop_diagnostics.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var node := Vector3(46.0, 0.0, 46.0)
    var inbound: Array[CivicLaneData] = []
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if Priority.is_controlled(lane) and Priority.axis_for_lane(lane) == "ns" and Priority.junction_for_lane(lane).distance_to(node) < 0.01:
            inbound.append(lane)
    if inbound.size() != 2:
        _fail("two NS inbound approaches missing")
        return
    inbound.sort_custom(func(a: CivicLaneData, b: CivicLaneData) -> bool:
        return a.lane_id < b.lane_id)
    var first_exit: int = -1
    var second_exit: int = -1
    for id in graph.outgoing_legal_lanes(inbound[0].lane_id, 1):
        first_exit = id
        break
    for id in graph.outgoing_legal_lanes(inbound[1].lane_id, 1):
        if id != first_exit:
            second_exit = id
            break
    if first_exit < 0 or second_exit < 0:
        _fail("nonconflicting outgoing lanes missing")
        return

    var first := _car(inbound[0], first_exit, 7.0)
    var second := _car(inbound[1], second_exit, 7.0)
    var stalled := CivicVehicleAgent.new()
    stalled.active = true
    stalled.route = PackedInt32Array([first_exit])
    stalled.lane_distance_m = Priority.EXIT_CLEARANCE_M + 0.25
    var cars: Array[CivicVehicleAgent] = [first, second, stalled]
    if Priority.occupies(stalled, graph, node):
        _fail("fixture is still inside the protected junction")
        return
    if Priority.exit_available(first, cars):
        _fail("blocked outbound exit incorrectly marked clear")
        return
    if not Priority.exit_available(second, cars):
        _fail("unrelated exit incorrectly marked occupied")
        return
    var hold: Dictionary = Priority.disposition(first, graph, cars, 1)
    var release: Dictionary = Priority.disposition(second, graph, cars, 1)
    if not bool(hold.get("yield", false)) or str(hold.get("reason", "")) != "outbound_blocked":
        _fail("nearby downstream queue did not hold the priority winner")
        return
    if bool(release.get("yield", true)):
        _fail("clear green approach starved behind blocked winner")
        return
    if StopDiag.outer_reason("outbound_blocked") != "outbound_blocked":
        _fail("outbound queue is not observable in diagnostics")
        return

    # Neither a red phase nor another car already inside the node may be
    # bypassed just because a different exit lane is empty.
    if not bool(Priority.disposition(second, graph, cars, 160).get("yield", false)):
        _fail("red right-of-way incorrectly granted")
        return
    stalled.lane_distance_m = 3.0
    if not Priority.occupies(stalled, graph, node):
        _fail("fixture did not re-enter occupied zone")
        return
    if str(Priority.disposition(second, graph, cars, 1).get("reason", "")) != "zone_occupied":
        _fail("occupied crossing was not protected")
        return

    stalled.lane_distance_m = Priority.OUTBOUND_QUEUE_CLEARANCE_M + 0.25
    if not Priority.exit_available(first, cars):
        _fail("cleared outbound lane never released")
        return
    var winner: Dictionary = Priority.disposition(first, graph, cars, 1)
    if bool(winner.get("yield", true)) or str(winner.get("reason", "")) != "granted":
        _fail("nearest approach did not regain green priority")
        return
    var again: Dictionary = Priority.disposition(first, graph, cars, 1)
    Priority.disposition(first, graph, cars, 160)
    if winner != again or winner != Priority.disposition(first, graph, cars, 1):
        _fail("priority choice changed with no saved world changes")
        return
    for car in cars:
        car.free()
    print("CIVIC_CHAOS_JUNCTION_FIX_03_OUTBOUND_CAPACITY_PASS")
    quit(0)

func _car(lane: CivicLaneData, outgoing_id: int, from_end: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.active = true
    car.route = PackedInt32Array([lane.lane_id, outgoing_id])
    car.current_route_index = 0
    car.lane_distance_m = lane.length_m() - from_end
    return car

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
