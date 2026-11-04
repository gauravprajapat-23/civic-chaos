extends SceneTree
## Run: godot --headless --path . --script res://tests/smoke_test.gd
## Intentional failure: append -- --force-fail to test CI failure handling.

const Registry = preload("res://scripts/core/scene_registry.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if "--force-fail" in OS.get_cmdline_user_args():
        push_error("CIVIC_CHAOS_INTENTIONAL_FAILURE")
        quit(1)
        return

    var checked: int = 0
    for path in Registry.all_scene_paths():
        if not ResourceLoader.exists(path):
            push_error("Missing scene: " + path)
            quit(1)
            return
        var resource := load(path)
        if not resource is PackedScene:
            push_error("Not a PackedScene: " + path)
            quit(1)
            return
        var scene := resource as PackedScene
        var instance := scene.instantiate()
        if instance == null:
            push_error("Failed to instantiate: " + path)
            quit(1)
            return
        instance.free()
        checked += 1
    print("CIVIC_CHAOS_SMOKE_PASS: %d scenes" % checked)
    quit(0)
