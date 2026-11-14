extends SceneTree
## AUD3-FIX-02: invalid/valid/rotation layout restores all touch targets.
const Controls = preload("res://scripts/ui/touch_controls.gd")
const Layout = preload("res://scripts/ui/touch_layout.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var controls: CivicTouchControls = Controls.new() as CivicTouchControls
    root.add_child(controls)
    await process_frame
    var portrait: Dictionary = Layout.joystick_plan(
        Vector2(360, 740), Rect2(Vector2(16, 24), Vector2(328, 688)))
    var landscape: Dictionary = Layout.joystick_plan(
        Vector2(740, 360), Rect2(Vector2(40, 10), Vector2(680, 340)))
    if not portrait.get("ok", false) or not landscape.get("ok", false):
        _fail("expected supported display geometry", controls)
        return

    controls._apply_plan(portrait, true)
    if not _check_controls(controls, true):
        _fail("portrait targets did not appear", controls)
        return
    controls.joystick._set_stick(controls.joystick.global_position + Vector2(0, -60))
    Input.action_press("jump")
    controls._apply_plan(Layout.joystick_plan(Vector2(180, 120)), true)
    if controls._layout_valid or not controls._rects.is_empty() or not _check_controls(controls, false):
        _fail("invalid geometry left touch targets or stale hitboxes", controls)
        return
    if Input.is_action_pressed("jump") or Input.is_action_pressed("move_forward"):
        _fail("invalid geometry left buttons or joystick pressed", controls)
        return
    controls._apply_plan(landscape, true)
    if not _check_controls(controls, true):
        _fail("landscape recovery did not restore every target", controls)
        return
    for action in ["jump", "sprint", "interact", "pause_game"]:
        if controls.look_touch_allowed((controls._rects[action] as Rect2).get_center()):
            _fail("camera look overlaps recovered " + action, controls)
            return

    controls.joystick._set_stick(controls.joystick.global_position + Vector2(0, -60))
    controls._apply_plan(portrait, true)
    if Input.is_action_pressed("move_forward") or controls.joystick.pointer_id != -1:
        _fail("orientation change retained movement gesture", controls)
        return
    controls._apply_plan(portrait, false)
    if not _check_controls(controls, false):
        _fail("desktop mode showed mobile-only actions", controls)
        return
    controls.queue_free()
    print("CIVIC_CHAOS_AUD3_RESPONSIVE_TOUCH_RECOVERY_PASS")
    quit(0)

func _check_controls(controls: CivicTouchControls, expected: bool) -> bool:
    if controls.joystick.visible != expected:
        return false
    for action in ["jump", "sprint", "interact", "pause_game"]:
        if (controls.buttons[action] as TouchScreenButton).visible != expected:
            return false
        if (controls.labels[action] as Label).visible != expected:
            return false
    return true

func _fail(message: String, controls: CivicTouchControls) -> void:
    controls.cancel_active_touches()
    push_error(message)
    quit(1)
