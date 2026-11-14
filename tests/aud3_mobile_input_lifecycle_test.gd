extends SceneTree
## AUD3-FIX-01: touch Pause/Use signals and no phantom input behind modals.
const Controls = preload("res://scripts/ui/touch_controls.gd")
const PlayerScene = preload("res://scenes/player/player_root.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # Standalone SceneTree tests do not instantiate CivicMain, which normally
    # registers controller camera-look actions in _enter_tree(). Provide only
    # missing names so the player physics tick never queries invalid actions.
    for action in ["look_left", "look_right", "look_up", "look_down"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var controls: CivicTouchControls = Controls.new() as CivicTouchControls
    root.add_child(controls)
    var player: CivicPlayerController = PlayerScene.instantiate() as CivicPlayerController
    root.add_child(player)
    await process_frame
    var presses := {"pause": 0, "use": 0}
    controls.pause_requested.connect(func() -> void: presses["pause"] += 1)
    controls.interact_requested.connect(func() -> void: presses["use"] += 1)
    (controls.buttons["pause_game"] as TouchScreenButton).pressed.emit()
    (controls.buttons["interact"] as TouchScreenButton).pressed.emit()
    if presses["pause"] != 1 or presses["use"] != 1:
        _fail("Pause and Use touch signals missing or emitted twice")
        return

    controls.joystick.enabled_on_desktop = true
    controls.joystick.visible = true
    controls.joystick._set_stick(controls.joystick.global_position + Vector2(0, -60))
    Input.action_press("jump")
    Input.action_press("sprint")
    player._look_touch_index = 5
    if not Input.is_action_pressed("move_forward"):
        _fail("movement fixture could not engage a held joystick")
        return
    controls.set_controls_active(false)
    player.cancel_mobile_look()
    if (controls.visible or controls.joystick.value != Vector2.ZERO
            or controls.joystick.pointer_id != -1 or player._look_touch_index != -1):
        _fail("modal did not reset held joystick and camera finger")
        return
    for action in ["move_left", "move_right", "move_forward", "move_back",
            "jump", "sprint", "interact", "pause_game"]:
        if Input.is_action_pressed(action):
            _fail("modal left action pressed: " + action)
            return
    # A touch underneath a modal must not recapture joystick ownership.
    var touch := InputEventScreenTouch.new()
    touch.index = 9
    touch.position = controls.joystick.global_position
    touch.pressed = true
    controls.joystick._input(touch)
    if controls.joystick.pointer_id != -1:
        _fail("hidden touch layer accepted a new joystick finger")
        return
    controls.set_controls_active(true)
    if not controls.visible:
        _fail("mobile controls did not restore after modal dismissal")
        return
    controls.queue_free()
    player.queue_free()
    print("CIVIC_CHAOS_AUD3_MOBILE_INPUT_LIFECYCLE_PASS")
    quit(0)

func _fail(message: String) -> void:
    for action in ["move_left", "move_right", "move_forward", "move_back",
            "jump", "sprint", "interact", "pause_game"]:
        if InputMap.has_action(action):
            Input.action_release(action)
    push_error(message)
    quit(1)
