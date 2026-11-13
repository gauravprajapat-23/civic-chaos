extends SceneTree
## ART-CAR-02: recover a walker staged inside a physically occupied car
## without ignoring vehicle collision or teleporting across the district.
const Pedestrians = preload("res://scripts/npc/district_pedestrians.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var spawner := Spawner.new() as CivicTrafficSpawner
    stage.add_child(spawner)

    var road := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 19
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -20)])
    if not road.add_lane(lane):
        _fail("vehicle route unavailable")
        return
    var car := CarScene.instantiate() as CivicVehicleAgent
    stage.add_child(car)
    if not car.configure(road, PackedInt32Array([19]), Profile.new()):
        _fail("real car did not configure")
        return
    spawner.active_vehicles.append(car)

    var walkers := Pedestrians.new()
    walkers.pedestrian_count = 1
    stage.add_child(walkers)
    walkers.set_physics_process(false)
    walkers.configure_traffic(null, spawner)
    if walkers._walkers.size() != 1:
        _fail("pedestrian was not created")
        return

    var person: Node3D = walkers._walkers[0]["root"]
    person.global_position = car.global_position
    await physics_frame
    if not walkers._resolve_actor_overlap(0, 0.05):
        _fail("walker was not recovered from the car footprint")
        return
    if person.global_position.distance_to(car.global_position) > 4.5:
        _fail("car overlap recovery teleported the pedestrian too far")
        return
    var local: Vector3 = car.to_local(person.global_position)
    if absf(local.x) < 1.20 and absf(local.z) < 1.85:
        _fail("pedestrian remained inside vehicle footprint")
        return
    if walkers._swept_path_blocked(0, person.position, person.position, true):
        _fail("pedestrian recovered into another physical obstruction")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_PEDESTRIAN_RECOVERY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
