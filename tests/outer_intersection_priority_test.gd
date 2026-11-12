extends SceneTree
## AUD2-MAP-02: deterministic noncentral right-of-way and physical walker yield.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Priority = preload("res://scripts/traffic/outer_intersection_priority.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    if not graph.validate().is_empty():
        _fail("outer junction fixture graph invalid")
        return
    var node := Vector3(46.0, 0.0, 46.0)
    var ns: Array[CivicLaneData] = []
    var ew: Array[CivicLaneData] = []
    for lane_id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(lane_id)
        if Priority.junction_for_lane(lane).distance_to(node) > 0.05:
            continue
        if Priority.axis_for_lane(lane) == "ns":
            ns.append(lane)
        elif Priority.axis_for_lane(lane) == "ew":
            ew.append(lane)
    if ns.size() != 2 or ew.size() != 2:
        _fail("outer four-way junction did not have two routes on each axis")
        return
    var central: CivicLaneData
    for lane_id in graph.sorted_lane_ids():
        var candidate: CivicLaneData = graph.get_lane(lane_id)
        if candidate.centerline[candidate.centerline.size() - 1].distance_to(Vector3.ZERO) <= 0.05:
            central = candidate
            break
    if central == null or Priority.is_controlled(central):
        _fail("outer policy unexpectedly took over central signal")
        return
    var ns_green: int = 0
    var ew_green: int = 0
    var all_red: int = 0
    for tick in range(Priority.PERIOD_TICKS):
        var n: bool = Priority.aspect("ns", tick) == "green"
        var e: bool = Priority.aspect("ew", tick) == "green"
        if n and e:
            _fail("conflicting approaches simultaneously authorized at tick " + str(tick))
            return
        ns_green += int(n)
        ew_green += int(e)
        all_red += int(not n and not e)
    if ns_green != 120 or ew_green != 120 or all_red != 80:
        _fail("outer cycle does not have both six-second greens and all-red clearance")
        return

    var spawner: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    if not spawner.configure(graph, 8899, true):
        _fail("outer policy spawner rejected valid city graph")
        return
    var north_car := _car(ns[0], 7.0)
    var other_north := _car(ns[1], 7.0)
    var east_car := _car(ew[0], 7.0)
    spawner.active_vehicles.append(north_car)
    spawner.active_vehicles.append(east_car)
    spawner.current_tick = 1

    if _stops(spawner, north_car) or not _stops(spawner, east_car):
        _fail("first NS phase failed to stop the perpendicular EW approach")
        return
    spawner.current_tick = 120
    if not _stops(spawner, north_car) or not _stops(spawner, east_car):
        _fail("all-red clearance did not hold both approaches")
        return
    spawner.current_tick = 160
    if not _stops(spawner, north_car) or _stops(spawner, east_car):
        _fail("EW phase did not reverse approach right-of-way")
        return

    spawner.active_vehicles.clear()
    spawner.active_vehicles.append(north_car)
    spawner.active_vehicles.append(other_north)
    spawner.current_tick = 1
    var first: CivicVehicleAgent = north_car if ns[0].lane_id < ns[1].lane_id else other_north
    var second: CivicVehicleAgent = other_north if first == north_car else north_car
    if _stops(spawner, first) or not _stops(spawner, second):
        _fail("opposite-direction tie did not select a single stable lane-ID winner")
        return
    # If two cars share the same lane and stop-line distance, saved fleet
    # order is the final tie-breaker; both must not enter in one fixed tick.
    var same_lane := _car(ns[0], 7.0)
    spawner.active_vehicles.clear()
    spawner.active_vehicles.append(north_car)
    spawner.active_vehicles.append(same_lane)
    if _stops(spawner, north_car) or not _stops(spawner, same_lane):
        _fail("same-lane tied vehicles received overlapping entrance rights")
        return
    # The checkpoint fleet slot, not ObjectDB creation order, breaks a
    # perfectly identical approach tie. Reversing slots must reverse the
    # winner without leaving both cars simultaneously authorized.
    spawner.active_vehicles.reverse()
    if _stops(spawner, same_lane) or not _stops(spawner, north_car):
        _fail("same-lane winner did not follow reversed saved fleet slots")
        return
    spawner.active_vehicles.clear()
    spawner.active_vehicles.append(north_car)
    spawner.active_vehicles.append(other_north)
    same_lane.free()
    # A mission/tow-stopped car at the entrance cannot starve unrelated
    # approaches; physical sweeps still protect it as a real obstacle.
    first.stop_requested = true
    first.lane_distance_m += 2.0
    if _stops(spawner, second):
        _fail("stopped approach monopolized the junction despite no entry")
        return
    first.stop_requested = false
    first.lane_distance_m -= 2.0
    # Distance dominates lane-ID when both arrivals are approaching one zone.
    second.lane_distance_m += 1.0
    if _stops(spawner, second) or not _stops(spawner, first):
        _fail("closer car was not prioritized over a smaller lane ID")
        return

    spawner.active_vehicles.clear()
    north_car.lane_distance_m = ns[0].length_m() - 3.0
    east_car.lane_distance_m = ew[0].length_m() - 7.0
    spawner.active_vehicles.append(north_car)
    spawner.active_vehicles.append(east_car)
    spawner.current_tick = 160
    if not Priority.occupies(north_car, graph, node) or not _stops(spawner, east_car):
        _fail("car already entering a crossing did not block a new green arrival")
        return
    if Priority.disposition(north_car, graph, spawner.active_vehicles, 160).get("reason") != "already_entered":
        _fail("committed car was abruptly stopped when its light switched")
        return
    var onward: Array[int] = graph.outgoing_legal_lanes(ns[0].lane_id, 1)
    if onward.is_empty():
        _fail("missing connected outgoing lane for clearance check")
        return
    north_car.route = PackedInt32Array([ns[0].lane_id, onward[0]])
    north_car.current_route_index = 1
    north_car.lane_distance_m = 3.0
    if not Priority.occupies(north_car, graph, node) or not _stops(spawner, east_car):
        _fail("outbound car released intersection too early")
        return
    north_car.lane_distance_m = Priority.EXIT_CLEARANCE_M + 0.25
    if Priority.occupies(north_car, graph, node) or _stops(spawner, east_car):
        _fail("cleared junction did not release waiting traffic")
        return

    # There must be no hidden policy state to diverge after F5/F9 clock
    # rewind; the same slots/lanes/tick produce the same decision.
    var before: Dictionary = Priority.disposition(east_car, graph, spawner.active_vehicles, 160)
    Priority.disposition(east_car, graph, spawner.active_vehicles, 319)
    var after: Dictionary = Priority.disposition(east_car, graph, spawner.active_vehicles, 160)
    if before != after or not before.get("controlled", false):
        _fail("fixed-tick replay changed after an unpersisted policy update")
        return

    spawner.active_vehicles.clear()
    spawner.active_vehicles.append(north_car)
    north_car.route = PackedInt32Array([ns[0].lane_id])
    north_car.current_route_index = 0
    north_car.lane_distance_m = ns[0].length_m() - 7.0
    spawner.current_tick = 1
    root.add_child(spawner)
    await physics_frame
    if _stops(spawner, north_car):
        _fail("empty outer crossing was blocked without a conflicting actor")
        return
    var walker := AnimatableBody3D.new()
    walker.collision_layer = 8
    walker.collision_mask = 0
    walker.position = node + Vector3.UP * 0.85
    var collider := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.6
    collider.shape = sphere
    walker.add_child(collider)
    root.add_child(walker)
    await physics_frame
    if not _stops(spawner, north_car):
        _fail("occupied outer crosswalk failed to yield to a real pedestrian collider")
        return
    walker.free()
    await physics_frame
    if _stops(spawner, north_car):
        _fail("freed pedestrian zone permanently blocked new vehicles")
        return
    spawner.active_vehicles.clear()
    spawner.free()
    north_car.free()
    other_north.free()
    east_car.free()
    print("CIVIC_CHAOS_OUTER_INTERSECTION_PRIORITY_PASS")
    quit(0)

func _car(lane: CivicLaneData, metres_before_end: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.active = true
    car.route = PackedInt32Array([lane.lane_id])
    car.current_route_index = 0
    car.lane_distance_m = lane.length_m() - metres_before_end
    car.minimum_gap_m = 2.0
    return car

func _stops(spawner: CivicTrafficSpawner, car: CivicVehicleAgent) -> bool:
    return bool(spawner.apply_stop_line_observation(car, {"detected": false}).get("detected", false))

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
