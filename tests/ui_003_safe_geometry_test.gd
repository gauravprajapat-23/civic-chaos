extends SceneTree
## UI-003: pure responsive geometry gate for cutouts, text scale and touch zones.
const Layout = preload("res://scripts/ui/civic_hud_safe_layout.gd")
const Board = preload("res://scripts/ui/free_roam_dispatch_board.gd")
var failures: int = 0

func _check(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error("UI-003: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for size in [Vector2(320, 568), Vector2(360, 640), Vector2(740, 360),
            Vector2(568, 320), Vector2(320, 740), Vector2(1280, 720)]:
        var safe := Rect2(Vector2(10, 24), size - Vector2(20, 42))
        var usable: Rect2 = Layout.usable(size, safe)
        var touch_left := Rect2(Vector2(0, size.y - 124), Vector2(145, 124))
        var touch_right := Rect2(Vector2(size.x - 148, size.y - 134), Vector2(148, 134))
        var top_tracker := Rect2(Vector2(0, 0), Vector2(size.x, 78))
        var exclusions: Array[Rect2] = [touch_left, touch_right, top_tracker]
        var mini: Rect2 = Layout.minimap(size, safe, exclusions)
        var calls: Rect2 = Layout.launcher(size, Vector2(92, 48), safe, exclusions, true)
        var full: Rect2 = Layout.panel(size, Vector2(530, 580), safe)
        _check(usable.encloses(full), "CALLS panel safe area " + str(size))
        _check(full.size.x > 0.0 and full.size.y > 0.0, "CALLS panel missing " + str(size))
        _check(usable.encloses(mini) or mini == Rect2(), "minimap outside safe area " + str(size))
        _check(not Layout.intersects_reserved(mini, exclusions), "minimap on controls " + str(size))
        if mini.has_area():
            var map_button := Rect2(Vector2(mini.position.x, mini.end.y + 4.0),
                Vector2(mini.size.x, 44.0))
            _check(usable.encloses(map_button), "MAP launcher outside safe area " + str(size))
            _check(not Layout.intersects_reserved(map_button, exclusions), "MAP launcher on controls " + str(size))
        if calls.has_area():
            _check(usable.encloses(calls), "CALLS launcher outside safe area " + str(size))
            _check(not Layout.intersects_reserved(calls, exclusions), "CALLS launcher on controls " + str(size))
            _check(calls.size.y >= 44.0, "CALLS launcher touch height " + str(size))
        if mini.has_area() and calls.has_area():
            var map_total := Rect2(mini.position, Vector2(mini.size.x, mini.size.y + 48.0))
            _check(not map_total.intersects(calls), "MAP/CALLS overlap " + str(size))
    _check(Layout.usable(Vector2.ZERO) == Rect2(), "zero viewport accepted")
    _check(Layout.minimap(Vector2(320, INF)) == Rect2(), "nonfinite viewport accepted")
    var saturated: Array[Rect2] = [Rect2(Vector2.ZERO, Vector2(320, 568))]
    _check(Layout.launcher(Vector2(320, 568), Vector2(92, 48), Rect2(), saturated) == Rect2(),
        "saturated exclusions must hide CALLS instead of stealing play controls")
    _check(Board.panel_bounds(Vector2(320, 568)).size.x > 0.0, "legacy bounds changed")
    if failures == 0:
        print("CIVIC_CHAOS_UI_003_SAFE_GEOMETRY_PASS")
    else:
        print("CIVIC_CHAOS_UI_003_SAFE_GEOMETRY_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
