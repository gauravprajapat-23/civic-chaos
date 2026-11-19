extends SceneTree
## GAME-025-02: dispatch is a read-only mirror of the real event director.
const Board = preload("res://scripts/ui/free_roam_dispatch_board.gd")
const Events = preload("res://scripts/civic/free_roam_events.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var player := Node3D.new()
    world.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    world.add_child(civic)
    if not civic.configure(world, player):
        _fail("gameplay session unavailable")
        return
    var events := Events.new() as CivicFreeRoamEvents
    world.add_child(events)
    if not events.configure(player, civic):
        _fail("free roam events did not configure")
        return

    var board := Board.new() as CivicFreeRoamDispatchBoard
    root.add_child(board)
    await process_frame
    if board.enabled or board.expanded or board.panel.visible:
        _fail("campaign mode unexpectedly exposed dispatch")
        return
    board.set_available(true)
    var idle: Dictionary = events.dispatch_state()
    board.update_feed(idle)
    if bool(idle["has_event"]) or not board.route_button.disabled or not board.status.text.contains("ALL CLEAR"):
        _fail("idle scheduler incorrectly claimed an active incident")
        return
    var calls: Array[String] = []
    board.toggle_requested.connect(func() -> void: calls.append("toggle"))
    board.route_requested.connect(func() -> void: calls.append("route"))
    board.button.pressed.emit()
    if calls != ["toggle"]:
        _fail("dispatch open button did not request toggle")
        return
    board.set_expanded(true)
    if not board.panel.visible or board.button.visible:
        _fail("expanded board did not replace the small button")
        return

    # A valid event descriptor here checks display mapping only. It never
    # resolves an event, grants rewards or changes director bookkeeping.
    events.active_event = {
        "kind": Events.SIGN, "site_id": "north_west", "stage": 0,
        "tier": "priority", "deadline_tick": events.tick + 45}
    var active: Dictionary = events.dispatch_state()
    if not bool(active["has_event"]) or not bool(active["priority"]) or not bool(active["has_target"]):
        _fail("active priority call did not expose its real waypoint")
        return
    board.update_feed(active)
    if board.route_button.disabled or not board.details.text.contains("45s") or not board.status.text.contains("PRIORITY"):
        _fail("priority call/distance display missing")
        return
    board.route_button.pressed.emit()
    if calls != ["toggle", "route"]:
        _fail("navigate button did not request city map")
        return
    events.active_event["stage"] = 2
    var carried: Dictionary = events.dispatch_state()
    if carried["target"] != CivicFreeRoamChallenges.site("north_west", Events.SIGN)["destination"]:
        _fail("dispatch waypoint did not switch to delivery destination")
        return
    events.active_event = {}
    board.update_feed(events.dispatch_state())
    if not board.route_button.disabled:
        _fail("inactive calls retained a stale map route")
        return
    board.close_button.pressed.emit()
    if calls != ["toggle", "route", "toggle"]:
        _fail("dispatch close button not connected")
        return
    board.set_expanded(false)
    board.set_available(false)
    if board.button.visible or board.panel.visible:
        _fail("dispatch visible after Free Roam lock")
        return
    board.queue_free()
    world.queue_free()
    print("CIVIC_CHAOS_GAME025_DISPATCH_BOARD_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
