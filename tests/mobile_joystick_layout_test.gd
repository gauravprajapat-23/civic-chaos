extends SceneTree
## MOB-CTRL-01: live mobile safe area layout must keep stick and actions apart.
const Layout = preload("res://scripts/ui/touch_layout.gd")

func _initialize() -> void:
    var cases := [
        {"screen": Vector2(320, 568), "safe": Rect2(Vector2(10, 16), Vector2(300, 536))},
        {"screen": Vector2(360, 740), "safe": Rect2(Vector2(16, 24), Vector2(328, 688))},
        {"screen": Vector2(740, 360), "safe": Rect2(Vector2(40, 10), Vector2(680, 340))},
        {"screen": Vector2(1280, 720), "safe": Rect2()},
        {"screen": Vector2(1920, 1080), "safe": Rect2(Vector2(48, 30), Vector2(1824, 1020))}
    ]
    for item in cases:
        var first: Dictionary = Layout.joystick_plan(item["screen"], item["safe"])
        var again: Dictionary = Layout.joystick_plan(item["screen"], item["safe"])
        if not bool(first.get("ok", false)) or first != again:
            _fail("mobile layout failed/replayed differently: " + str(item))
            return
        var safe: Rect2 = first["safe_rect"]
        var center: Vector2 = first["joystick_center"]
        var radius: float = float(first["joystick_radius"])
        var stick := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
        if not safe.encloses(stick):
            _fail("joystick clipped by notch or screen edge")
            return
        var rects: Dictionary = first["rects"]
        if rects.size() != 4:
            _fail("right action count is incorrect")
            return
        for action in ["jump", "sprint", "interact", "pause_game"]:
            var rect: Rect2 = rects[action]
            if not safe.encloses(rect) or rect.grow(4.0).intersects(stick):
                _fail("action overlaps joystick or is outside safe area: " + action)
                return
            for other in rects:
                if action != other and rect.grow(2.0).intersects((rects[other] as Rect2).grow(2.0)):
                    _fail("actions overlap: " + action + " / " + other)
                    return
    for invalid in [Vector2.ZERO, Vector2(200, 180), Vector2(INF, 720)]:
        if bool(Layout.joystick_plan(invalid).get("ok", false)):
            _fail("accepted invalid viewport " + str(invalid))
            return
    print("CIVIC_CHAOS_MOBILE_JOYSTICK_LAYOUT_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
