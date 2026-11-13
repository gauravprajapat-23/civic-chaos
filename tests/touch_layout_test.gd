extends SceneTree
## UI-01: pure safe-area layout geometry, no live touch-control activation.
## Test rectangles, not just whether the buttons existed at startup.
const Layout = preload("res://scripts/ui/touch_layout.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var cases: Array[Dictionary] = [
        {"screen": Vector2(360, 740), "safe": Rect2(Vector2(16, 24), Vector2(328, 688))},
        {"screen": Vector2(720, 1280), "safe": Rect2(Vector2(0, 38), Vector2(720, 1194))},
        {"screen": Vector2(740, 360), "safe": Rect2(Vector2(40, 10), Vector2(680, 340))},
        {"screen": Vector2(1280, 720), "safe": Rect2(Vector2.ZERO, Vector2(1280, 720))},
        {"screen": Vector2(1920, 1080), "safe": Rect2(Vector2(48, 30), Vector2(1824, 1020))},
        {"screen": Vector2(1280, 800), "safe": Rect2(Vector2(0, 0), Vector2(1280, 800))},
        {"screen": Vector2(320, 568), "safe": Rect2(Vector2(10, 16), Vector2(300, 536))}
    ]
    for item in cases:
        if not _verify_case(item["screen"], item["safe"]):
            return
    # Missing safe-area information defaults to the complete viewport.
    if not _verify_case(Vector2(360, 740), Rect2()):
        return
    for invalid in [
        {"screen": Vector2.ZERO, "safe": Rect2()},
        {"screen": Vector2(180, 120), "safe": Rect2()},
        {"screen": Vector2(360, 740), "safe": Rect2(Vector2(-500, -500), Vector2(20, 20))},
        {"screen": Vector2(360, 740), "safe": Rect2(Vector2.ZERO, Vector2(-10, 720))},
        {"screen": Vector2(INF, 740), "safe": Rect2()}
    ]:
        if bool(Layout.plan(invalid["screen"], invalid["safe"]).get("ok", false)):
            _fail("invalid viewport or safe area was accepted: " + str(invalid))
            return
    print("CIVIC_CHAOS_TOUCH_LAYOUT_PASS")
    quit(0)

func _verify_case(viewport: Vector2, safe_input: Rect2) -> bool:
    var first: Dictionary = Layout.plan(viewport, safe_input)
    if not bool(first.get("ok", false)):
        return _fail("safe-area layout rejected supported viewport " + str(viewport) + ": " + str(first))
    var second: Dictionary = Layout.plan(viewport, safe_input)
    if first != second:
        return _fail("same safe area produced a different layout on replay")
    var safe_rect: Rect2 = first["safe_rect"]
    var button_size: Vector2 = first["button_size"]
    var rects: Dictionary = first["rects"]
    if button_size.x < 44.0 or button_size.x > 72.0 or button_size.x != button_size.y:
        return _fail("touch target not square or outside supported readable size")
    if rects.size() != Layout.ACTIONS.size():
        return _fail("touch target count mismatch")
    for i in range(Layout.ACTIONS.size()):
        var action: String = Layout.ACTIONS[i]
        if not rects.has(action):
            return _fail("missing input: " + action)
        var rectangle: Rect2 = rects[action]
        if not safe_rect.encloses(rectangle) or rectangle.size != button_size:
            return _fail("button outside safe area or incorrectly sized: " + action)
        for j in range(i + 1, Layout.ACTIONS.size()):
            var other: Rect2 = rects[Layout.ACTIONS[j]]
            if rectangle.grow(2.0).intersects(other.grow(2.0)):
                return _fail("buttons overlap after 2-pixel padding: " + action + " / " + Layout.ACTIONS[j])
    var up: Rect2 = rects["move_forward"]
    var down: Rect2 = rects["move_back"]
    var left: Rect2 = rects["move_left"]
    var right: Rect2 = rects["move_right"]
    if up.position.y >= down.position.y or left.position.x >= right.position.x:
        return _fail("directional cross has incorrect orientation")
    var pause: Rect2 = rects["pause_game"]
    var interact: Rect2 = rects["interact"]
    if pause.position.y >= interact.position.y:
        return _fail("pause overlapped the bottom-right action cluster")
    return true

func _fail(message: String) -> bool:
    push_error(message)
    quit(1)
    return false
