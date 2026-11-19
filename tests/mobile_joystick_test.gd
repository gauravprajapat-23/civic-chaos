extends SceneTree
## MOB-CTRL-01: analog joystick deadzone, diagonals and touch release.
const Joystick = preload("res://scripts/ui/mobile_joystick.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_forward", "move_back", "move_left", "move_right"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var neutral: Vector2 = Joystick.normalized_offset(Vector2(102, 98), Vector2(100, 100), 70.0)
    if neutral != Vector2.ZERO:
        _fail("joystick deadzone did not suppress small jitter")
        return
    var full: Vector2 = Joystick.normalized_offset(Vector2(200, 100), Vector2(100, 100), 70.0)
    if absf(full.x - 1.0) > 0.001 or absf(full.y) > 0.001:
        _fail("joystick right reach was not clamped to one")
        return
    var diagonal: Vector2 = Joystick.normalized_offset(Vector2(150, 50), Vector2(100, 100), 70.0)
    if diagonal.x < 0.6 or diagonal.y > -0.6 or diagonal.length() > 1.001:
        _fail("joystick diagonal was unnormalized or reversed")
        return

    var stick: CivicMobileJoystick = Joystick.new() as CivicMobileJoystick
    root.add_child(stick)
    stick.configure(Vector2(105, 310), 75.0)
    stick._set_stick(Vector2(155, 260))
    if not Input.is_action_pressed("move_right") or not Input.is_action_pressed("move_forward"):
        _fail("diagonal joystick did not drive both movement actions")
        return
    if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_back"):
        _fail("joystick incorrectly drove opposite actions")
        return
    if Input.get_action_strength("move_right") < 0.4:
        _fail("joystick analog strength missing")
        return
    # Genuine touch index ownership: other fingers may look or jump.
    stick.enabled_on_desktop = true
    stick.visible = true
    stick.release_stick()
    var first := InputEventScreenTouch.new()
    first.index = 3
    first.position = Vector2(105, 310)
    first.pressed = true
    stick._input(first)
    if stick.pointer_id != 3:
        _fail("movement finger was not captured")
        return
    var second := InputEventScreenTouch.new()
    second.index = 7
    second.position = Vector2(145, 310)
    second.pressed = true
    stick._input(second)
    if stick.pointer_id != 3:
        _fail("second camera/action finger stole movement stick")
        return
    var drag := InputEventScreenDrag.new()
    drag.index = 3
    drag.position = Vector2(105, 250)
    stick._input(drag)
    if not Input.is_action_pressed("move_forward"):
        _fail("captured movement finger stopped controlling forward motion")
        return
    var other_release := InputEventScreenTouch.new()
    other_release.index = 7
    other_release.pressed = false
    other_release.position = second.position
    stick._input(other_release)
    if stick.pointer_id != 3:
        _fail("second finger released first finger's joystick")
        return
    var first_release := InputEventScreenTouch.new()
    first_release.index = 3
    first_release.pressed = false
    first_release.position = first.position
    stick._input(first_release)
    if stick.pointer_id != -1 or stick.value != Vector2.ZERO:
        _fail("captured joystick finger release did not reset state")
        return
    stick.release_stick()
    for action in CivicMobileJoystick.AXES:
        if Input.is_action_pressed(action):
            _fail("joystick did not release " + action)
            return
    stick.queue_free()
    print("CIVIC_CHAOS_MOBILE_JOYSTICK_PASS")
    quit(0)

func _fail(message: String) -> void:
    for action in ["move_forward","move_back","move_left","move_right"]:
        Input.action_release(action)
    push_error(message)
    quit(1)
