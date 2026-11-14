extends SceneTree
## AUD3-TRAFFIC: white civic information slabs must not block driving lanes.
const MarkerScene = preload("res://scenes/world/interaction_marker.tscn")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const MainScene = preload("res://scenes/core/main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var main: Node3D = MainScene.instantiate() as Node3D
    if main == null:
        _fail("main scene not instantiated")
        return
    var marker: StaticBody3D = main.get_node_or_null("CivicInfoPoint") as StaticBody3D
    if marker == null:
        _fail("central information marker missing")
        return
    if marker.position.distance_to(Vector3(0, 0, -3)) < 3.0:
        _fail("solid white information marker still placed on road crossing")
        return
    if marker.position.x > -6.0 or marker.position.z > -8.0:
        _fail("information point not positioned off the driving lane")
        return
    if marker.collision_layer != 16:
        _fail("information marker must use interaction-only layer 16")
        return
    main.free()

    var world := Node3D.new()
    root.add_child(world)
    var point: StaticBody3D = MarkerScene.instantiate() as StaticBody3D
    point.position = Vector3(0, 0, -3)
    world.add_child(point)
    var car: CivicVehicleAgent = VehicleScene.instantiate() as CivicVehicleAgent
    car.feedback_enabled = false
    car.position = point.position
    world.add_child(car)
    await physics_frame
    if car.footprint_blocked_at(car.global_transform):
        _fail("interaction-only white sign obstructs physical vehicle footprint")
        return
    var road_blocker := StaticBody3D.new()
    road_blocker.collision_layer = 1
    road_blocker.collision_mask = 0
    var shape := CollisionShape3D.new()
    var cube := BoxShape3D.new()
    cube.size = Vector3(1.2, 1.8, 0.6)
    shape.shape = cube
    shape.position.y = 0.9
    road_blocker.add_child(shape)
    world.add_child(road_blocker)
    road_blocker.global_position = car.global_position
    await physics_frame
    if not car.footprint_blocked_at(car.global_transform):
        _fail("real solid road obstacle bypassed after marker collision fix")
        return
    world.queue_free()
    print("CIVIC_CHAOS_AUD3_ROAD_MARKER_CLEARANCE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
