extends SceneTree
## AUD2-MAP-03: actual collidable vehicles exercise an outer four-way junction.
## The test is physics-frame driven; no direct-space queries from idle loops.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Priority = preload("res://scripts/traffic/outer_intersection_priority.gd")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    if not graph.validate().is_empty():
        _fail("invalid city graph")
        return
    var junction := Vector3(46.0, 0.0, 46.0)
    var north_lane: CivicLaneData
    var east_lane: CivicLaneData
    for lane_id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(lane_id)
        if Priority.junction_for_lane(lane).distance_to(junction) > 0.05:
            continue
        if Priority.axis_for_lane(lane) == "ns" and north_lane == null:
            north_lane = lane
        elif Priority.axis_for_lane(lane) == "ew" and east_lane == null:
            east_lane = lane
    if north_lane == null or east_lane == null:
        _fail("missing perpendicular outer approaches")
        return
    var stage := Node3D.new()
    root.add_child(stage)
    var spawner := Spawner.new() as CivicTrafficSpawner
    spawner.spawn_interval_ticks = 100000
    stage.add_child(spawner)
    if not spawner.configure(graph, 1212, true):
        _fail("spawner failed to configure")
        return
    var ns: CivicVehicleAgent = _make_car(spawner, graph, north_lane)
    var ew: CivicVehicleAgent = _make_car(spawner, graph, east_lane)
    if ns == null or ew == null:
        _fail("failed to create two physical vehicles")
        return
    spawner.active_vehicles.append(ns)
    spawner.active_vehicles.append(ew)
    # Start with a real pedestrian body in the conflict zone. Cars must not
    # drive through it, even while their axis otherwise has green.
    var walker := AnimatableBody3D.new()
    walker.collision_layer = 8
    walker.collision_mask = 0
    walker.position = junction + Vector3.UP * 0.85
    var walker_shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.6
    walker_shape.shape = sphere
    walker.add_child(walker_shape)
    stage.add_child(walker)
    await physics_frame
    var ns_entered := false
    var ew_entered := false
    var ns_advanced := false
    var ew_advanced := false
    for tick in range(1, 321):
        # All collision queries and transforms are evaluated at real physics
        # boundaries, not from an idle callback with a potentially locked space.
        await physics_frame
        if tick == 41:
            walker.queue_free()
            await physics_frame
        spawner.advance_fixed(tick, 0.05)
        if not is_instance_valid(ns) or not is_instance_valid(ew):
            _fail("a car ended its route before crossing the junction")
            return
        # Distance to the junction is an inexpensive independent physical
        # guard; the actual vehicle footprint sweep remains enabled.
        var a := ns.global_position
        var b := ew.global_position
        a.y = 0.0
        b.y = 0.0
        if a.distance_to(b) < 1.5:
            _fail("two physical vehicle bodies overlapped at tick " + str(tick))
            return
        var ns_out: bool = ns.current_route_index > 0
        var ew_out: bool = ew.current_route_index > 0
        if tick <= 40 and ns.lane_distance_m > north_lane.length_m() - Priority.STOP_LINE_M + 0.06:
            _fail("NS vehicle entered occupied pedestrian crossing")
            return
        if tick < 160 and ew.lane_distance_m > east_lane.length_m() - Priority.STOP_LINE_M + 0.06:
            _fail("EW vehicle entered before its own green")
            return
        ns_entered = ns_entered or ns_out
        ew_entered = ew_entered or ew_out
        ns_advanced = ns_advanced or (ns_out and ns.lane_distance_m > Priority.EXIT_CLEARANCE_M)
        ew_advanced = ew_advanced or (ew_out and ew.lane_distance_m > Priority.EXIT_CLEARANCE_M)
    if not ns_entered or not ew_entered or not ns_advanced or not ew_advanced:
        _fail("physical traffic deadlocked or did not clear outbound crossing")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_OUTER_INTERSECTION_MOVEMENT_PASS")
    quit(0)

func _make_car(spawner: CivicTrafficSpawner, graph: CivicRoadGraph, lane: CivicLaneData) -> CivicVehicleAgent:
    var onward: Array[int] = graph.outgoing_legal_lanes(lane.lane_id, 1)
    if onward.is_empty():
        return null
    var car := VehicleScene.instantiate() as CivicVehicleAgent
    if car == null:
        return null
    spawner.add_child(car)
    # Disable optional visual feedback only; retain physical collision checks.
    car.feedback_enabled = false
    if not car.configure(graph, PackedInt32Array([lane.lane_id, onward[0]]), Profile.new()):
        car.queue_free()
        return null
    car.lane_distance_m = lane.length_m() - 9.0
    car._place_on_lane()
    car.physics_obstacle_checks_enabled = true
    return car

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
