extends SceneTree
const Controls = preload("res://scripts/ui/touch_controls.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var controls := Controls.new()
    root.add_child(controls)
    await process_frame
    assert(controls.buttons.size() == 8)
    for action in controls.actions:
        var button := controls.buttons[action] as TouchScreenButton
        assert(button.action == action)
        assert(button.shape != null)
        assert(button.position.x >= 0.0)
        assert(button.position.y >= 0.0)
    controls._layout()
    controls.queue_free()
    print("CIVIC_CHAOS_TOUCH_CONTROLS_PASS")
    quit(0)
