extends SceneTree
## Green traffic must pass secondary intersections without sidewalk slabs.
## Retain real building walls and collision checks for actual hazards.
const Neighborhood = preload("res://scenes/world/neighborhood.tscn")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Vehicle = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var district := Neighborhood.instantiate() as Node3D
    world.add_child(district)
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var lane_id: int = -1
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        var start: Vector3 = lane.centerline[0]
        var finish: Vector3 = lane.centerline[lane.centerline.size() - 1]
        if absf(start.x - 46.0) < 0.01 and absf(start.z) < 0.01 and absf(finish.x - 46.0) < 0.01 and absf(finish.z - 46.0) < 0.01:
            lane_id = id
            break
    if lane_id < 0:
        _fail("missing road from central east axis to northeast signal")
        return
    var car := Vehicle.instantiate() as CivicVehicleAgent
    car.feedback_enabled = false
    world.add_child(car)
    if not car.configure(graph, PackedInt32Array([lane_id]), Profile.new()):
        _fail("car could not configure")
        return
    await physics_frame
    for sidewalk_name in ["SidewalkX-1", "SidewalkX1", "SidewalkZ-1", "SidewalkZ1"]:
        var sidewalk := district.get_node_or_null(sidewalk_name) as StaticBody3D
        if sidewalk == null or sidewalk.collision_layer != 0:
            _fail("continuous sidewalk still has solid car-blocking collider: " + sidewalk_name)
            return
    var lane: CivicLaneData = graph.get_lane(lane_id)
    for distance in [3.0, 4.2, 5.0, 5.8, 7.0, 9.0, 12.0]:
        var pose: Dictionary = car.sample_centerline(lane.centerline, distance)
        var direction: Vector3 = pose["tangent"]
        var transform := Transform3D(Basis(Vector3.UP, atan2(-direction.x, -direction.z)), pose["position"])
        if car.footprint_blocked_at(transform):
            _fail("raised geometry obstructs secondary road at z=%0.2f" % float(distance))
            return
    car.physics_obstacle_checks_enabled = true
    for i in range(180):
        await physics_frame
        car.advance_fixed(0.05)
        if not car.active or car.lane_distance_m > 13.0:
            break
    if car.lane_distance_m <= 13.0:
        _fail("real car stuck crossing former sidewalk collision slab")
        return
    world.queue_free()
    print("CIVIC_CHAOS_AUD3_SECONDARY_ROAD_CLEARANCE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
