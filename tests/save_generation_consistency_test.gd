extends SceneTree
## GAME-018 — player and civic actors must use the exact verified generation
## read at the beginning of the checkpoint transaction, not a later F5.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Repo = preload("res://scripts/core/save_repository.gd")
const Lifecycle = preload("res://scripts/core/game_lifecycle.gd")
const PATH: String = "user://game018_generation_consistency.json"

func _initialize() -> void:
    call_deferred("_run")

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        var name: String = PATH + suffix
        if FileAccess.file_exists(name):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(name))

func _payload(x: float) -> Dictionary:
    return {"player": {"x": x, "y": 0.1, "z": 0.0, "yaw": 0.25}}

func _run() -> void:
    _clean()
    for action in ["move_left", "move_right", "move_forward", "move_back",
        "look_left", "look_right", "look_up", "look_down", "sprint", "jump"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var world := Node3D.new()
    root.add_child(world)
    var floor := StaticBody3D.new()
    floor.collision_layer = 1
    floor.collision_mask = 0
    floor.position.y = -0.25
    var floor_shape := CollisionShape3D.new()
    var slab := BoxShape3D.new()
    slab.size = Vector3(40.0, 0.5, 40.0)
    floor_shape.shape = slab
    floor.add_child(floor_shape)
    world.add_child(floor)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(0.0, 0.2, 4.0)
    world.add_child(player)
    var lifecycle := Lifecycle.new() as CivicGameLifecycle
    world.add_child(lifecycle)
    await physics_frame
    if not Repo.write_save(_payload(-3.0), PATH):
        _fail("could not save generation A")
        return
    var generation_a: Dictionary = Repo.read_save(PATH)
    if not Repo.write_save(_payload(3.0), PATH):
        _fail("could not save generation B")
        return
    if not lifecycle.load_player_snapshot(player, generation_a):
        _fail("exact A snapshot was not queued")
        return
    await physics_frame
    await physics_frame
    if absf(player.global_position.x + 3.0) > 0.25:
        _fail("player loaded a newer generation instead of the verified A snapshot")
        return
    if not lifecycle.load_player(player, PATH):
        _fail("latest B generation was not queued")
        return
    await physics_frame
    await physics_frame
    if absf(player.global_position.x - 3.0) > 0.25:
        _fail("explicit latest-generation load did not select committed B")
        return
    world.queue_free()
    _clean()
    print("CIVIC_CHAOS_SAVE_GENERATION_CONSISTENCY_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    _clean()
    quit(1)
