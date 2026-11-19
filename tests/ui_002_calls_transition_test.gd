extends SceneTree
## UI-002: repeat CALLS transitions, focus ownership and responsive hitboxes.
const Dispatch = preload("res://scripts/ui/free_roam_dispatch_board.gd")
const Controls = preload("res://scripts/ui/touch_controls.gd")
const Layout = preload("res://scripts/ui/touch_layout.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var home := Button.new()
    home.text = "Home focus"
    root.add_child(home)
    var controls: CivicTouchControls = Controls.new() as CivicTouchControls
    root.add_child(controls)
    var board: CivicFreeRoamDispatchBoard = Dispatch.new() as CivicFreeRoamDispatchBoard
    root.add_child(board)
    await process_frame
    board.set_available(true)
    home.grab_focus()
    for cycle in range(3):
        Input.action_press("jump")
        board.set_expanded(true)
        if Input.is_action_pressed("jump") or not board.panel.visible:
            _fail("opening CALLS retained action input")
            return
        board.set_expanded(true) # Idempotent; must not overwrite focus origin.
        if board._focus_before_open == null or board._focus_before_open.get_ref() != home:
            _fail("repeated open replaced original focus")
            return
        Input.action_press("sprint")
        board.set_expanded(false)
        if Input.is_action_pressed("sprint") or board.panel.visible or get_focus_owner() != home:
            _fail("closing CALLS did not release input and restore focus")
            return
    board.set_expanded(true)
    home.hide()
    board.set_expanded(false)
    if get_focus_owner() == home:
        _fail("closing CALLS focused a hidden control")
        return
    home.show()
    board.set_expanded(true)
    board.set_available(false)
    if board.expanded or board.panel.visible or board.button.visible:
        _fail("disabled dispatch left modal or launcher visible")
        return
    for viewport in [Vector2(320, 568), Vector2(740, 360), Vector2(360, 740), Vector2(568, 320)]:
        var rect: Rect2 = Dispatch.panel_bounds(viewport)
        var launcher: Rect2 = Dispatch.open_button_bounds(viewport)
        var visible_area := Rect2(Vector2.ZERO, viewport)
        if not visible_area.encloses(rect) or not visible_area.encloses(launcher):
            _fail("CALLS escaped screen after rotation " + str(viewport))
            return
    var portrait := Layout.joystick_plan(Vector2(360, 740))
    var landscape := Layout.joystick_plan(Vector2(740, 360))
    if not bool(portrait.get("ok", false)) or not bool(landscape.get("ok", false)):
        _fail("supported orientation touch layout invalid")
        return
    controls._apply_plan(portrait, true)
    Input.action_press("interact")
    controls._apply_plan(landscape, true)
    if Input.is_action_pressed("interact"):
        _fail("orientation retained touch action")
        return
    board.queue_free()
    controls.queue_free()
    home.queue_free()
    print("CIVIC_CHAOS_UI_002_CALLS_TRANSITION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
