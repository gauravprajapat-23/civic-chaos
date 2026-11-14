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
