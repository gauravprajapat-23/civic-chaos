extends SceneTree
## Real physics-frame save validation and safe recovery, using a test-only save.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Repo = preload("res://scripts/core/save_repository.gd")
const Lifecycle = preload("res://scripts/core/game_lifecycle.gd")
const TEST_SAVE = "user://civic_chaos_physics_restore_test.json"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_left", "move_right", "move_forward", "move_back", "look_left", "look_right", "look_up", "look_down", "sprint", "jump"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.collision_layer = 1
    ground.collision_mask = 0
    ground.position.y = -0.25
    var floor_shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(40, 0.5, 40)
    floor_shape.shape = floor_box
    ground.add_child(floor_shape)
    stage.add_child(ground)
    var obstacle := StaticBody3D.new()
    obstacle.collision_layer = 1
    obstacle.collision_mask = 0
    obstacle.position = Vector3(5.0, 1.0, 0.0)
    var obstacle_shape := CollisionShape3D.new()
    var obstacle_box := BoxShape3D.new()
    obstacle_box.size = Vector3(2.0, 2.0, 2.0)
    obstacle_shape.shape = obstacle_box
    obstacle.add_child(obstacle_shape)
    stage.add_child(obstacle)

    # Occupied saves must also reject cars and pedestrians, not just walls.
    var parked_car := StaticBody3D.new()
    parked_car.collision_layer = 4
    parked_car.collision_mask = 0
    parked_car.position = Vector3(-5.0, 0.7, 0.0)
    var car_shape := CollisionShape3D.new()
    var car_box := BoxShape3D.new()
    car_box.size = Vector3(1.6, 1.2, 3.0)
    car_shape.shape = car_box
    parked_car.add_child(car_shape)
    stage.add_child(parked_car)
    var pedestrian := AnimatableBody3D.new()
    pedestrian.collision_layer = 8
    pedestrian.collision_mask = 0
    pedestrian.position = Vector3(0.0, 0.0, -4.0)
    var npc_shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.75
    npc_shape.shape = capsule
    npc_shape.position.y = 0.87
    pedestrian.add_child(npc_shape)
    stage.add_child(pedestrian)

    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(0.0, 0.2, 4.0)
    stage.add_child(player)
    var manager := Lifecycle.new()
    stage.add_child(manager)
    await physics_frame
    if not Repo.write_save({"player": {"x": -3.0, "y": 0.1, "z": 0.0, "yaw": 0.4}}, TEST_SAVE):
        _fail("failed to write valid test save")
        return
    if not manager.load_player(player, TEST_SAVE):
        _fail("valid restore was not queued")
        return
    await physics_frame
    await physics_frame
    if absf(player.global_position.x + 3.0) > 0.2 or absf(player.global_position.z) > 0.2 or absf(player.rotation.y - 0.4) > 0.01:
        _fail("safe saved position was not applied on physics tick")
        return

    # Every unsafe location must recover to the known clear spawn.
    for unsafe in [
        Vector3(5.0, 0.1, 0.0),   # inside a building
        Vector3(-5.0, 0.1, 0.0),  # parked vehicle
        Vector3(0.0, 0.1, -4.0),  # pedestrian
        Vector3(999.0, 0.1, 0.0) # outside all supported terrain
    ]:
        var sample := {"player": {
            "x": unsafe.x, "y": unsafe.y, "z": unsafe.z, "yaw": 0.0
        }}
        if not Repo.write_save(sample, TEST_SAVE):
            _fail("failed to write unsafe-location test save")
            return
        if not manager.load_player(player, TEST_SAVE):
            _fail("unsafe save not queued for physics validation")
            return
        await physics_frame
        await physics_frame
        if player.global_position.distance_to(Vector3(0.0, 0.12, 4.0)) > 0.3:
            _fail("unsafe save did not recover near spawn: " + str(unsafe))
            return

    # Falling through a gap must also choose a grounded, unoccupied position.
    player.global_position = Vector3(0.0, -9.0, 4.0)
    player.velocity = Vector3.ZERO
    await physics_frame
    await physics_frame
    if player.global_position.distance_to(Vector3(0.0, 0.12, 4.0)) > 0.3:
        _fail("fall recovery did not restore world-supported position")
        return
    stage.queue_free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    print("CIVIC_CHAOS_PLAYER_SAFE_RESTORE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    quit(1)
