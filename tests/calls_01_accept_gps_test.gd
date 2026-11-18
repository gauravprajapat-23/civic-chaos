extends SceneTree
## CALLS-01: live incident acceptance remains read-only and GPS routes
## only accepted, still-active calls to real coordinates.
const Dispatch = preload("res://scripts/ui/free_roam_dispatch_board.gd")
const CityMap = preload("res://scripts/ui/civic_city_map.gd")
const RoadBuilder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dispatch := Dispatch.new() as CivicFreeRoamDispatchBoard
    root.add_child(dispatch)
    var map := CityMap.new() as CivicCityMap
    root.add_child(map)
    await process_frame
    dispatch.set_available(true)

    var accepts := [0]
    var routes := [0]
    dispatch.accept_requested.connect(func() -> void: accepts[0] += 1)
    dispatch.route_requested.connect(func() -> void: routes[0] += 1)

    var live: Dictionary = {
        "has_event": true, "call_id": 50017,
        "title": "Fallen Public Sign", "location": "Market Chowk",
        "priority": true, "seconds_left": 110, "stage": 0,
        "objective": "Inspect the fallen sign",
        "has_target": true, "target": Vector3(18, 0, -26),
        "resolved": 2, "expired": 1
    }
    dispatch.update_feed(live)
    if dispatch.accepted_live_call() or not dispatch.route_button.disabled:
        _fail("unaccepted event already has an active GPS route")
        return
    dispatch.accept_button.pressed.emit()
    if accepts[0] != 1:
        _fail("accept UI does not signal gameplay controller")
        return
    if not dispatch.accept_live_call(50017) or not dispatch.accepted_live_call():
        _fail("could not accept current live incident")
        return
    if dispatch.route_button.disabled or not dispatch.accept_button.disabled:
        _fail("acceptance did not unlock GPS or suppress repeat acceptance")
        return
    if dispatch.accept_live_call(50018):
        _fail("a forged non-current call ID was accepted")
        return

    var guidance: Dictionary = {
        "title": "DISPATCH | Fallen Public Sign",
        "objective": "Inspect the fallen sign",
        "has_target": true, "target": live["target"]
    }
    map.set_road_graph(RoadBuilder.make_city_graph())
    map.update_position(Vector3(2, 0, 0), Vector3.FORWARD, guidance)
    map._select_location(-1)
    if not bool(map.route_state.get("ok", false)) or (
            (map.route_state.get("points", PackedVector3Array()) as PackedVector3Array).size() < 2):
        _fail("accepted call did not generate a road-network route")
        return
    if map._navigation_goal().get("target") != live["target"]:
        _fail("GPS target is not the current live incident position")
        return
    dispatch.route_button.pressed.emit()
    if routes[0] != 1:
        _fail("accepted live call cannot open map navigation")
        return

    # Current incident's objective changes during inspection or carrying.
    # The map should use the new physical destination for the same ID.
    live["stage"] = 2
    live["target"] = Vector3(21, 0, -28)
    live["objective"] = "Deliver the recovered sign"
    dispatch.update_feed(live)
    if not dispatch.accepted_live_call():
        _fail("same incident lost acceptance while progressing stages")
        return
    guidance["target"] = live["target"]
    map.update_position(Vector3(18, 0, -26), Vector3.FORWARD, guidance)
    if map._navigation_goal().get("target") != live["target"]:
        _fail("map did not follow advanced incident destination")
        return

    # A different live event must never inherit the previous acceptance.
    live["call_id"] = 50018
    dispatch.update_feed(live)
    if dispatch.accepted_live_call() or not dispatch.route_button.disabled:
        _fail("new incident inherited prior GPS acceptance")
        return
    if dispatch.accept_live_call(50017):
        _fail("stale incident ID was accepted after replacement")
        return
    if not dispatch.accept_live_call(50018):
        _fail("new real call cannot be accepted")
        return
    live["has_event"] = false
    live["has_target"] = false
    live["call_id"] = -1
    dispatch.update_feed(live)
    if dispatch.accepted_live_call() or not dispatch.route_button.disabled:
        _fail("resolved or expired incident retained navigation")
        return
    dispatch.set_available(false)
    if dispatch.accept_live_call(50018):
        _fail("locked Free Roam board accepted a call")
        return

    dispatch.queue_free()
    map.queue_free()
    print("CIVIC_CHAOS_CALLS_01_ACCEPT_GPS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
