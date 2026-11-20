extends SceneTree
## MASTER-HUD-004: exact touch planner, logical insets, modal preservation.
const MasterHud = preload("res://scripts/core/master_hud_layout.gd")
const Layout = preload("res://scripts/ui/civic_hud_safe_layout.gd")
const MapUI = preload("res://scripts/ui/civic_city_map.gd")
const Calls = preload("res://scripts/ui/free_roam_dispatch_board.gd")
var failures: int = 0

func _check(value: bool, message: String) -> void:
    if not value:
        failures += 1
        push_error("MASTER-HUD-004: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var safe_px := Rect2i(Vector2i(20, 48), Vector2i(600, 1070))
    var logical := MasterHud.logical_safe_area(Vector2(320, 568),
        safe_px, Vector2i(640, 1136))
    _check(logical == Rect2(Vector2(10, 24), Vector2(300, 535)),
        "display safe area scaling differs from touch controls")
    _check(MasterHud.logical_safe_area(Vector2.ZERO, safe_px,
        Vector2i(640, 1136)) == Rect2(), "zero viewport accepted")
    for viewport in [Vector2(320, 568), Vector2(360, 740),
            Vector2(568, 320), Vector2(740, 360), Vector2(1280, 720)]:
        var safe := Rect2(Vector2(10, 24), viewport - Vector2(20, 42))
        var plan: Dictionary = MasterHud.plan(viewport, safe, true)
        var map_rect: Rect2 = plan["map_rect"]
        var calls_rect: Rect2 = plan["calls_rect"]
        var map_reserved: Array[Rect2] = plan["map_reserved"]
        var calls_reserved: Array[Rect2] = plan["calls_reserved"]
        var usable: Rect2 = Layout.usable(viewport, safe)
        _check(map_rect.has_area(), "MAP launcher inaccessible on " + str(viewport))
        _check(calls_rect.has_area(), "CALLS launcher inaccessible on " + str(viewport))
        if map_rect.has_area():
            var map_all := Rect2(map_rect.position,
                Vector2(map_rect.size.x, map_rect.size.y + 48.0))
            _check(usable.encloses(map_all), "MAP outside inset viewport")
            _check(not Layout.intersects_reserved(map_all, map_reserved),
                "MAP occludes touch/guide HUD")
            _check(not map_all.intersects(calls_rect), "MAP overlaps CALLS")
        if calls_rect.has_area():
            _check(usable.encloses(calls_rect), "CALLS outside safe viewport")
            _check(not Layout.intersects_reserved(calls_rect, calls_reserved),
                "CALLS overlaps touch/guide/MAP")
    var blocked: Dictionary = MasterHud.plan(Vector2(300, 250), Rect2(), true)
    _check(not (blocked["map_rect"] as Rect2).has_area() and
        not (blocked["calls_rect"] as Rect2).has_area(),
        "invalid touch area allowed HUD launchers")
    var map: CivicCityMap = MapUI.new() as CivicCityMap
    var board: CivicFreeRoamDispatchBoard = Calls.new() as CivicFreeRoamDispatchBoard
    root.add_child(map)
    root.add_child(board)
    await process_frame
    board.set_available(true)
    board.update_feed({"has_event": true, "call_id": 4004,
        "has_target": true, "title": "Pothole report",
        "objective": "Inspect reported damage", "seconds_left": 90})
    _check(board.accept_live_call(4004), "cannot accept original dispatch")
    map.selected_location = 2
    var viewport: Vector2 = root.get_visible_rect().size
    for simulated_size in [Vector2(320, 568), Vector2(740, 360),
            Vector2(568, 320)]:
        # UI node geometry uses the actual viewport; assertions about
        # simulated viewports are covered above by the pure layout planner.
        var planned: Dictionary = MasterHud.plan(viewport, Rect2(), false)
        var map_exclusions: Array[Rect2] = planned["map_reserved"]
        var calls_exclusions: Array[Rect2] = planned["calls_reserved"]
        map.set_hud_constraints(Rect2(), map_exclusions)
        board.set_hud_constraints(Rect2(), calls_exclusions)
        _check(board.accepted_live_call() and board.accepted_call_id == 4004,
            "layout change erased accepted call " + str(simulated_size))
        _check(map.selected_location == 2,
            "layout change erased selected waypoint " + str(simulated_size))
    board.queue_free()
    map.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_MASTER_HUD_004_PASS")
    else:
        print("CIVIC_CHAOS_MASTER_HUD_004_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
