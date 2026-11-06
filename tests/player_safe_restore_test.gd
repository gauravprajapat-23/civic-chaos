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

    if not Repo.write_save({"player": {"x": 5.0, "y": 0.1, "z": 0.0, "yaw": 0.0}}, TEST_SAVE):
        _fail("failed to write blocked-location test save")
        return
    if not manager.load_player(player, TEST_SAVE):
        _fail("blocked save was unexpectedly rejected before the physics check")
        return
    await physics_frame
    await physics_frame
    if player.global_position.distance_to(Vector3(0.0, 0.12, 4.0)) > 0.3:
        _fail("blocked building location did not safely recover near spawn")
        return

    if not Repo.write_save({"player": {"x": 999.0, "y": 0.1, "z": 0.0, "yaw": 0.0}}, TEST_SAVE):
        _fail("failed to write out-of-world test save")
        return
    if not manager.load_player(player, TEST_SAVE):
        _fail("out-of-world save not queued for validation")
        return
    await physics_frame
    await physics_frame
    if player.global_position.distance_to(Vector3(0.0, 0.12, 4.0)) > 0.3:
        _fail("out-of-world save did not recover to the safe spawn")
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
