extends SceneTree

const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 1
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(30, 0, 0)])
    graph.add_lane(lane)
    var car := VehicleScene.instantiate() as CivicVehicleAgent
    stage.add_child(car)
    if not car.configure(graph, PackedInt32Array([1]), Profile.new()):
        _fail("car configuration rejected")
        return
    var player := CharacterBody3D.new()
    player.collision_layer = 2
    player.collision_mask = 1 | 4
    player.position = Vector3(5.0, 0.0, 0.0)
    stage.add_child(player)
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    var collider := CollisionShape3D.new()
    collider.shape = capsule
    collider.position.y = 0.9
    player.add_child(collider)
    await physics_frame
    for tick in range(200):
        car.advance_fixed(0.05)
        await physics_frame
    if car.global_position.x > 2.5:
        _fail("car entered player safety envelope")
        return
    if car.speed_mps > 0.01:
        _fail("car did not stop before player")
        return
    player.position = Vector3(5.0, 0.0, 10.0)
    await physics_frame
    for tick in range(120):
        car.advance_fixed(0.05)
        await physics_frame
        if car.global_position.x > 6.0:
            break
    if car.global_position.x <= 6.0:
        _fail("car did not resume after player cleared")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_OBSTACLE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
