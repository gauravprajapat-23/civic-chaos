extends SceneTree
## Keep every headless fixture fail-closed; a bare assert() may abort before
## SceneTree.quit() and leave the Python runner waiting for a timeout.
const Controls = preload("res://scripts/ui/touch_controls.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var controls := Controls.new()
    root.add_child(controls)
    await process_frame
    if controls.buttons.size() != 8 or controls.labels.size() != 8:
        _fail("touch controls did not create eight action hitboxes and labels")
        return
    for action in controls.actions:
        var button := controls.buttons.get(action) as TouchScreenButton
        var caption := controls.labels.get(action) as Label
        if button == null or caption == null:
            _fail("action missing a button or caption: " + action)
            return
        if button.action != action or button.shape == null:
            _fail("action binding or hitbox missing: " + action)
            return
        if button.position.x < 0.0 or button.position.y < 0.0:
            _fail("action is outside the visible top/left viewport: " + action)
            return
    controls._layout()
    controls.queue_free()
    print("CIVIC_CHAOS_TOUCH_CONTROLS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
