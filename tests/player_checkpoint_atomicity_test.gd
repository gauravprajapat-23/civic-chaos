extends SceneTree
## AUD-001: the full civic checkpoint must know whether the player was
## ACTUALLY placed on valid ground, not merely queued for a future tick.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Lifecycle = preload("res://scripts/core/game_lifecycle.gd")

func _initialize() -> void:
    call_deferred("_run")

func _snapshot(position: Vector3, yaw: float) -> Dictionary:
    return {"player": {
        "x": position.x, "y": position.y, "z": position.z, "yaw": yaw
    }}

func _run() -> void:
    for action in [
        "move_left", "move_right", "move_forward", "move_back", "look_left",
        "look_right", "look_up", "look_down", "sprint", "jump"
    ]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.collision_layer = 1
    floor.collision_mask = 0
    floor.position.y = -0.25
    var floor_shape := CollisionShape3D.new()
    var slab := BoxShape3D.new()
    slab.size = Vector3(40.0, 0.5, 40.0)
    floor_shape.shape = slab
    floor.add_child(floor_shape)
    stage.add_child(floor)

    var obstacle := StaticBody3D.new()
    obstacle.collision_layer = 1
    obstacle.collision_mask = 0
    obstacle.position = Vector3(5.0, 1.0, 0.0)
    var collision := CollisionShape3D.new()
    var cube := BoxShape3D.new()
    cube.size = Vector3(2.0, 2.0, 2.0)
    collision.shape = cube
    obstacle.add_child(collision)
    stage.add_child(obstacle)

    var player: CivicPlayerController = PlayerScene.instantiate() as CivicPlayerController
    if player == null:
        _fail("player PackedScene did not load")
        return
    player.position = Vector3(0.0, 0.2, 4.0)
    stage.add_child(player)
    var lifecycle: CivicGameLifecycle = Lifecycle.new() as CivicGameLifecycle
    stage.add_child(lifecycle)
    await physics_frame

    var safe: Dictionary = _snapshot(Vector3(-3.0, 0.1, 0.0), 0.25)
    if not lifecycle.restore_player_snapshot_now(player, safe):
        _fail("legitimate same-tick checkpoint placement failed")
        return
    if absf(player.global_position.x + 3.0) > 0.2 or absf(player.rotation.y - 0.25) > 0.01:
        _fail("accepted checkpoint was only queued, not physically applied")
        return
    var placed: Vector3 = player.global_position
    var yaw: float = player.rotation.y
    var blocked: Dictionary = _snapshot(Vector3(5.0, 0.1, 0.0), 0.9)
    if lifecycle.restore_player_snapshot_now(player, blocked):
        _fail("full checkpoint accepted a player inside a solid building")
        return
    if player.global_position.distance_to(placed) > 0.01 or absf(player.rotation.y - yaw) > 0.01:
        _fail("rejected full checkpoint moved or rotated the player")
        return
    if player._restore_pending:
        _fail("failed immediate placement queued a later teleport")
        return
    var outside: Dictionary = _snapshot(Vector3(999.0, 0.1, 0.0), -0.5)
    if lifecycle.restore_player_snapshot_now(player, outside):
        _fail("full checkpoint accepted an unsupported world position")
        return
    await physics_frame
    await physics_frame
    if player.global_position.distance_to(placed) > 0.2:
        _fail("rejected checkpoint teleported the player on a later physics frame")
        return
    if not lifecycle.load_player_snapshot(player, _snapshot(Vector3(0.0, 0.1, 0.0), 0.4)):
        _fail("legacy deferred player restore API stopped accepting safe requests")
        return
    if not player._restore_pending:
        _fail("deferred player-only restore no longer queues physical placement")
        return
    await physics_frame
    await physics_frame
    if player._restore_pending or player.global_position.distance_to(Vector3(0.0, 0.12, 0.0)) > 0.2:
        _fail("player-only compatibility path did not restore on a later physics tick")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_PLAYER_CHECKPOINT_ATOMICITY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
