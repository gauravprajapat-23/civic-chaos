extends SceneTree
## UI-001: responsive CALLS panel, scrollable actions and state-safe modal transitions.
const Dispatch = preload("res://scripts/ui/free_roam_dispatch_board.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for viewport in [Vector2(320, 568), Vector2(360, 640), Vector2(740, 360), Vector2(1280, 720)]:
        var rect: Rect2 = Dispatch.panel_bounds(viewport)
        if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not Rect2(Vector2.ZERO, viewport).encloses(rect):
            _fail("CALLS panel outside viewport: " + str(viewport))
            return
    if Dispatch.panel_bounds(Vector2.ZERO) != Rect2() or Dispatch.panel_bounds(Vector2(INF, 360)) != Rect2():
        _fail("invalid viewport accepted")
        return
    var board := Dispatch.new() as CivicFreeRoamDispatchBoard
    root.add_child(board)
    await process_frame
    if board.content_scroll == null or board.content_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        _fail("CALLS panel must scroll vertically without horizontal overflow")
        return
    for action in [board.accept_button, board.route_button, board.service_button, board.close_button]:
        if action.custom_minimum_size.y < 48.0:
            _fail("CALLS touch target smaller than 48px")
            return
    board.set_available(true)
    board.set_expanded(true)
    if not board.panel.visible or board.button.visible:
        _fail("expanded CALLS visibility is incorrect")
        return
    var report := {"has_event": true, "call_id": 6001, "has_target": true,
        "title": "Roadside debris", "location": "Market", "objective": "Inspect",
        "service_type": "SANITATION", "seconds_left": 70}
    board.update_feed(report)
    if not board.accept_live_call(6001) or board.route_button.disabled:
        _fail("GPS route action lost after CALLS layout change")
        return
    board.set_expanded(false)
    board.set_expanded(true)
    if not board.accepted_live_call() or board.route_button.disabled:
        _fail("modal reopen lost accepted-call route state")
        return
    board.set_available(false)
    if board.panel.visible or board.button.visible or board.accepted_live_call():
        _fail("unavailable dispatch retained visible or accepted state")
        return
    board.queue_free()
    print("CIVIC_CHAOS_UI_001_CALLS_RESPONSIVE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
