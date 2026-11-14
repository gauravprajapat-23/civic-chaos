extends SceneTree
## MOB-CTRL-01: real mobile control nodes and action hitbox contract.
const Controls = preload("res://scripts/ui/touch_controls.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var controls: CivicTouchControls = Controls.new() as CivicTouchControls
    root.add_child(controls)
    await process_frame
    if controls.joystick == null or controls.joystick.radius < 36.0:
        _fail("circular analog joystick missing")
        return
    if controls.buttons.size() != 4 or controls.labels.size() != 4:
        _fail("new layout must provide four distinct actions")
        return
    for action in controls.actions:
        var button := controls.buttons.get(action) as TouchScreenButton
        var caption := controls.labels.get(action) as Label
        if button == null or caption == null:
            _fail("missing button/label: " + action)
            return
        if button.action != action or not (button.shape is CircleShape2D) or button.texture_normal == null:
            _fail("circular action hitbox/texture missing: " + action)
            return
        if button.position.x <= 0.0 or button.position.y <= 0.0:
            _fail("action outside viewport: " + action)
            return
        var expected: Rect2 = controls._rects[action]
        if (button.position.distance_to(expected.position) > 0.01
                or absf(button.scale.x * 96.0 - expected.size.x) > 0.01):
            _fail("action image and hitbox are not aligned: " + action)
            return
    var jump: Rect2 = controls._rects["jump"]
    if controls.look_touch_allowed(jump.get_center()):
        _fail("tapping Jump also captures the look finger")
        return
    if not controls.look_touch_allowed(Vector2(controls.get_viewport().get_visible_rect().size.x * 0.5, 100.0)):
        _fail("free look space was incorrectly blocked")
        return
    controls._layout()
    controls.queue_free()
    print("CIVIC_CHAOS_TOUCH_CONTROLS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
