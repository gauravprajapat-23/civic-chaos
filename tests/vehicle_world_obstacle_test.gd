extends SceneTree
## A car must pass over the road floor but stop at a solid world obstruction.
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := _box("RoadFloor", Vector3(15, -0.25, 0), Vector3(40, 0.5, 10), 1)
    stage.add_child(floor)
    var building := _box("Building", Vector3(9, 1.0, 0), Vector3(2, 2, 3), 1)
    stage.add_child(building)
    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 1
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(30, 0, 0)])
    graph.add_lane(lane)
    var car := VehicleScene.instantiate() as CivicVehicleAgent
    stage.add_child(car)
    if not car.configure(graph, PackedInt32Array([1]), Profile.new()):
        _fail("vehicle configuration failed")
        return
    await physics_frame
    for frame in range(120):
        car.advance_fixed(0.05)
        await physics_frame
    if car.global_position.x < 2.0:
        _fail("floor was incorrectly treated as car obstacle")
        return
    if car.global_position.x > 7.2:
        _fail("car passed through building collision")
        return
    building.global_position = Vector3(9, 1.0, 9.0)
    await physics_frame
    for frame in range(120):
        car.advance_fixed(0.05)
        await physics_frame
        if car.global_position.x > 11.0:
            break
    if car.global_position.x <= 11.0:
        _fail("car did not resume after world obstacle cleared")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_WORLD_OBSTACLE_PASS")
    quit(0)

func _box(title: String, at: Vector3, dims: Vector3, layer: int) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = title
    body.position = at
    body.collision_layer = layer
    body.collision_mask = 0
    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var shape := BoxShape3D.new()
    shape.size = dims
    collision.shape = shape
    body.add_child(collision)
    return body

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
