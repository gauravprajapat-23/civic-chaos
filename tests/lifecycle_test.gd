extends SceneTree
## Executable save format, invalid-data and scene contract regression tests.

const Repo = preload("res://scripts/core/save_repository.gd")
const Lifecycle = preload("res://scripts/core/game_lifecycle.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var path := "user://cc005_lifecycle_test.json"
    var player := Node3D.new()
    player.position = Vector3(3.25, 1.0, -7.5)
    player.rotation.y = 0.75
    var sample := {"player": {"x": 3.25, "y": 1.0, "z": -7.5, "yaw": 0.75}}
    if not Repo.write_save(sample, path):
        _fail("save write failed")
        return
    var loaded: Dictionary = Repo.read_save(path)
    if loaded.get("version") != 1 or loaded.get("player", {}).get("x") != 3.25:
        _fail("round-trip mismatch")
        return
    var broken := FileAccess.open(path, FileAccess.WRITE)
    broken.store_string("{not valid json")
    broken.close()
    if not Repo.read_save(path).is_empty():
        _fail("corrupt save accepted")
        return
    if Repo.write_save({"player": {"x": 0.0}}, path):
        _fail("incomplete save accepted")
        return
    if not ResourceLoader.exists("res://scenes/core/menu.tscn"):
        _fail("menu scene missing")
        return
    var menu := load("res://scenes/core/menu.tscn") as PackedScene
    if menu == null:
        _fail("menu scene invalid")
        return
    var menu_instance: Node = menu.instantiate()
    if menu_instance == null:
        _fail("menu scene could not instantiate")
        return
    # SceneTree does not own an unparented PackedScene instance. Without
    # free(), it leaks Label/Font RIDs and ObjectDB nodes at engine exit.
    menu_instance.free()
    var manager := Lifecycle.new()
    if not manager.has_method("set_paused") or not manager.has_method("restart_game"):
        _fail("lifecycle API missing")
        return
    root.add_child(manager)
    manager.set_paused(true)
    if not paused:
        _fail("pause did not affect SceneTree")
        return
    manager.set_paused(false)
    if paused:
        _fail("resume did not clear SceneTree pause")
        return
    root.remove_child(manager)
    manager.free()
    player.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("CIVIC_CHAOS_LIFECYCLE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
