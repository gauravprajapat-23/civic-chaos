extends SceneTree
## JUNCTION-FIX-03B: central four-way occupancy remains safe without a
## controller, while a configured controller and pedestrian reservation
## remain authoritative and release immediately once their blockers clear.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Priority = preload("res://scripts/traffic/central_intersection_priority.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    if not spawner.configure(graph, 1234):
        _fail("isolated junction graph invalid")
        return
    var north := _car(PackedInt32Array([1, 4]), graph.get_lane(1).length_m() - 7.0)
    var east := _car(PackedInt32Array([3, 2]), graph.get_lane(3).length_m() - 7.0)
    spawner.active_vehicles.append(north)
    spawner.active_vehicles.append(east)
    var empty := {"detected": false}
    if bool(spawner.apply_stop_line_observation(north, empty).get("detected", false)):
        _fail("first empty central approach blocked")
        return
    if not bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("opposing approach incorrectly co-authorized on same tick")
        return

    # A crossing car must remain protected across the inbound/outbound
    # route transition; a safe distance beyond the exit releases access.
    north.lane_distance_m = graph.get_lane(1).length_m() - 3.0
    if not Priority.occupies(north, graph) or not bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("inbound conflict occupant was not protected")
        return
    north.current_route_index = 1
    north.lane_distance_m = 3.0
    if not Priority.occupies(north, graph) or not bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("outbound conflict occupant was released too early")
        return
    north.lane_distance_m = Priority.EXIT_CLEARANCE_M + 0.3
    if Priority.occupies(north, graph) or bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("cleared central junction did not immediately release its next contender")
        return
    north.stop_requested = true
    north.current_route_index = 0
    north.lane_distance_m = graph.get_lane(1).length_m() - 7.0
    if bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("mission-held contender starved an unrelated arrival")
        return

    # Actual city signals take precedence over any stateless tie break.
    north.stop_requested = false
    var signals := Signals.new(4.0, 2.0, 1.0)
    var reservations := Reservations.new()
    spawner.configure_intersection(signals, reservations)
    if not bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("red phase incorrectly authorized east car")
        return
    signals.advance_fixed(7.0)
    if bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("green east phase failed to release without a real occupant")
        return

    var person_id: int = 100001
    var zone := "pedestrian_crossing_ew"
    var result: Dictionary = reservations.request(person_id,
        PackedStringArray([zone]), 0, 50)
    if not bool(result.get("granted", false)) or not reservations.occupy(person_id, zone):
        _fail("pedestrian crossing reservation fixture invalid")
        return
    if not bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("green signal incorrectly overrode pedestrian crossing ownership")
        return
    if not reservations.release(person_id, zone):
        _fail("verified pedestrian exit could not release reservation")
        return
    reservations.cancel(person_id)
    if bool(spawner.apply_stop_line_observation(east, empty).get("detected", false)):
        _fail("stale green hold remained after safe pedestrian exit")
        return

    # No hidden priority cursor: identical fleet snapshot and phase must
    # produce identical grants on replay and after reading other phases.
    var before: Dictionary = Priority.disposition(east, graph,
        spawner.active_vehicles, graph.get_lane(3).length_m() - 5.0 - east.lane_distance_m, signals)
    var again: Dictionary = Priority.disposition(east, graph,
        spawner.active_vehicles, graph.get_lane(3).length_m() - 5.0 - east.lane_distance_m, signals)
    if before != again or bool(before.get("yield", true)):
        _fail("green crossing decision was not reproducible")
        return
    spawner.active_vehicles.clear()
    north.free()
    east.free()
    spawner.free()
    print("CIVIC_CHAOS_JUNCTION_FIX_03B_CENTRAL_RELEASE_PASS")
    quit(0)

func _car(ids: PackedInt32Array, progress: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.active = true
    car.route = ids
    car.lane_distance_m = progress
    car.minimum_gap_m = 2.0
    return car

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
