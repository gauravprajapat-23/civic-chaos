extends SceneTree
## UI-003: repeated MAP/CALLS transitions preserve UI state, focus and touch rules.
const Board = preload("res://scripts/ui/free_roam_dispatch_board.gd")
const CityMap = preload("res://scripts/ui/civic_city_map.gd")
var errors: int = 0

func _assert(value: bool, description: String) -> void:
    if not value:
        errors += 1
        push_error("UI-003: " + description)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var board: CivicFreeRoamDispatchBoard = Board.new()
    var map: CivicCityMap = CityMap.new()
    root.add_child(board)
    root.add_child(map)
    await process_frame
    board.set_available(true)
    var feed := {"has_event": true, "call_id": 7703, "has_target": true,
        "title": "A very long civic mission with an unusually verbose title for a narrow phone",
        "location": "Market Chowk south-west pedestrian route",
        "objective": "Investigate the report without obscuring gameplay",
        "seconds_left": 80, "service_type": "MAINTENANCE"}
    board.update_feed(feed)
    _assert(board.accept_live_call(7703), "live call could not be accepted")
    var view: Vector2 = root.get_visible_rect().size
    var safe := Rect2(Vector2(18, 30), view - Vector2(36, 54))
    var occupied: Array[Rect2] = [Rect2(Vector2(0, view.y - 130), Vector2(170, 130)),
        Rect2(Vector2(view.x - 180, view.y - 130), Vector2(180, 130)),
        Rect2(Vector2(0, 0), Vector2(view.x, 90))]
    board.set_hud_constraints(safe, occupied)
    map.set_hud_constraints(safe, occupied)
    for i in range(6):
        board.set_expanded(true)
        _assert(board.panel.visible and not board.button.visible, "CALLS modal failed to open")
        _assert(safe.encloses(Rect2(board.panel.position, board.panel.size)),
            "CALLS modal outside safe bounds")
        _assert(board.accepted_live_call() and not board.route_button.disabled,
            "CALLS accepted target/route lost on reflow")
        board.set_expanded(false)
        map.set_expanded(true)
        _assert(map.large_frame.visible and not map.map_button.visible,
            "MAP modal not exclusive")
        _assert(safe.encloses(Rect2(map.large_frame.position, map.large_frame.size)),
            "MAP overlay outside safe bounds")
        map.set_expanded(false)
        _assert(not board.expanded and not map.expanded, "modal remained expanded")
    board.service_requested_for(7703, "WAITING FOR CLEAR ROAD")
    _assert(board.response_status == "WAITING FOR CLEAR ROAD",
        "service status changed by layout-only operation")
    board.update_feed({"has_event": false, "seconds_until_next": 12})
    _assert(not board.accepted_live_call() and board.route_button.disabled,
        "expired incident still actionable")
    board.set_available(false)
    _assert(not board.button.visible and not board.panel.visible, "unavailable CALLS still visible")
    board.queue_free()
    map.queue_free()
    if errors == 0:
        print("CIVIC_CHAOS_UI_003_MODAL_REFLOW_PASS")
    else:
        print("CIVIC_CHAOS_UI_003_MODAL_REFLOW_FAIL %d" % errors)
    quit(0 if errors == 0 else 1)
