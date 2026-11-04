extends SceneTree
## Run: godot --headless --path . --script res://tests/smoke_test.gd

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for path in SceneRegistry.all_scene_paths():
        if not ResourceLoader.exists(path):
            push_error("Missing scene: " + path)
            quit(1)
            return
        var scene := load(path) as PackedScene
        if scene == null or scene.instantiate() == null:
            push_error("Invalid scene: " + path)
            quit(1)
            return
    print("CIVIC_CHAOS_SMOKE_PASS")
    quit(0)
