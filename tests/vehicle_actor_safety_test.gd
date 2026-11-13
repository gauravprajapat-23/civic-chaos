extends SceneTree
## ART-CAR-02: moving cars must never enter an occupied player's or
## pedestrian's physical capsule. Removing the actor lets traffic resume.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)

    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 17
    lane.centerline = PackedVector3Array([
        Vector3(0.0, 0.0, 9.0), Vector3(0.0, 0.0, -15.0)
    ])
    if not graph.add_lane(lane):
        _fail("test road graph rejected lane")
        return

    var car: CivicVehicleAgent = CarScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("physical car scene failed to instantiate")
        return
    stage.add_child(car)
    car.physics_obstacle_checks_enabled = true

    var player := CharacterBody3D.new()
    player.name = "PlayerRoot"
    player.collision_layer = 2
    player.collision_mask = 1
    var player_shape := CollisionShape3D.new()
    var player_capsule := CapsuleShape3D.new()
    player_capsule.radius = 0.35
    player_capsule.height = 1.8
    player_shape.shape = player_capsule
    player_shape.position = Vector3(0.0, 0.9, 0.0)
    player.add_child(player_shape)
    player.position = Vector3.ZERO
    stage.add_child(player)

    var walker := AnimatableBody3D.new()
    walker.name = "Pedestrian"
    walker.collision_layer = 8
    walker.collision_mask = 0
    var walker_shape := CollisionShape3D.new()
    var walker_capsule := CapsuleShape3D.new()
    walker_capsule.radius = 0.32
    walker_capsule.height = 1.75
    walker_shape.shape = walker_capsule
    walker_shape.position = Vector3(0.0, 0.87, 0.0)
    walker.add_child(walker_shape)
    walker.position = Vector3(8.0, 0.0, 0.0)
    stage.add_child(walker)
    await physics_frame

    if not car.configure(graph, PackedInt32Array([17]), Profile.new()):
        _fail("physical car failed to configure")
        return
    if not await _assert_stop_then_release(car, player, "player"):
        return
    player.position.x = 8.0
    walker.position.x = 0.0
    await physics_frame
    if not car.configure(graph, PackedInt32Array([17]), Profile.new()):
        _fail("physical car could not reset for pedestrian test")
        return
    if not await _assert_stop_then_release(car, walker, "pedestrian"):
        return
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_ACTOR_SAFETY_PASS")
    quit(0)

func _assert_stop_then_release(car: CivicVehicleAgent, actor: Node3D,
        label: String) -> bool:
    var approached: bool = false
    var stopped: bool = false
    for frame in range(180):
        await physics_frame
        car.advance_fixed(0.05)
        if car.global_position.z < 7.0:
            approached = true
        if car.global_position.z < 1.65:
            return _fail("%s was penetrated by approaching vehicle" % label)
        if approached and car.speed_mps < 0.05:
            stopped = true
            break
    if not approached or not stopped:
        return _fail("car did not approach and brake before %s" % label)
    var stopped_z: float = car.global_position.z
    actor.position.x = 8.0
    await physics_frame
    for frame in range(60):
        await physics_frame
        car.advance_fixed(0.05)
    if car.global_position.z >= stopped_z - 0.8:
        return _fail("vehicle stayed frozen after %s cleared road" % label)
    return true

func _fail(reason: String) -> bool:
    push_error(reason)
    quit(1)
    return false
