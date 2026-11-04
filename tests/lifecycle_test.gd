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
        return _fail("save write failed")
    var loaded: Dictionary = Repo.read_save(path)
    if loaded.get("version") != 1 or loaded.get("player", {}).get("x") != 3.25:
        return _fail("round-trip mismatch")
    var broken := FileAccess.open(path, FileAccess.WRITE)
    broken.store_string("{not valid json")
    broken.close()
    if not Repo.read_save(path).is_empty():
        return _fail("corrupt save accepted")
    if Repo.write_save({"player": {"x": 0.0}}, path):
        return _fail("incomplete save accepted")
    if not ResourceLoader.exists("res://scenes/core/menu.tscn"):
        return _fail("menu scene missing")
    var menu := load("res://scenes/core/menu.tscn") as PackedScene
    if menu == null or menu.instantiate() == null:
        return _fail("menu scene invalid")
    var manager := Lifecycle.new()
    if not manager.has_method("set_paused") or not manager.has_method("restart_game"):
        return _fail("lifecycle API missing")
    manager.free()
    player.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("CIVIC_CHAOS_LIFECYCLE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
