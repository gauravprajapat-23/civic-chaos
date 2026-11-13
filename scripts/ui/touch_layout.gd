class_name CivicTouchLayout
extends RefCounted
## Pure responsive hitbox geometry for CivicTouchControls.
## Staged only: no live Control or TouchScreenButton uses it until AUD-001
## Godot import, regression, campaign and Android acceptance have passed.
##
## All rectangles share one viewport-space safe area, so the hitbox and
## caption will eventually use the same origin and dimensions.

const ACTIONS := [
    "move_forward", "move_back", "move_left", "move_right",
    "jump", "sprint", "interact", "pause_game"
]
const MIN_BUTTON_PX: float = 44.0
const MAX_BUTTON_PX: float = 72.0
const EDGE_PX: float = 8.0
const GAP_PX: float = 6.0
const CENTER_GAP_PX: float = 12.0

static func plan(viewport_size: Vector2, requested_safe: Rect2 = Rect2()) -> Dictionary:
    if not viewport_size.is_finite() or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return _invalid("invalid_viewport")
    if not requested_safe.position.is_finite() or not requested_safe.size.is_finite():
        return _invalid("invalid_safe_area")
    if requested_safe.size.x < 0.0 or requested_safe.size.y < 0.0:
        return _invalid("invalid_safe_area")

    var whole: Rect2 = Rect2(Vector2.ZERO, viewport_size)
    var usable: Rect2 = whole if requested_safe.size == Vector2.ZERO else requested_safe.intersection(whole)
    if usable.size.x <= 0.0 or usable.size.y <= 0.0:
        return _invalid("safe_area_outside_viewport")

    # Five columns: three for a directional cross, two for actions.
    # Two movement gaps, one action gap and a central no-touch gutter.
    # Height must reserve a separate pause row above the action cluster.
    var width_cap: float = (usable.size.x - 2.0 * EDGE_PX - 3.0 * GAP_PX - CENTER_GAP_PX) / 5.0
    var movement_height_cap: float = (usable.size.y - 2.0 * EDGE_PX - 2.0 * GAP_PX) / 3.0
    var pause_height_cap: float = (usable.size.y - 3.0 * EDGE_PX - GAP_PX) / 3.0
    var edge: float = floorf(minf(MAX_BUTTON_PX, minf(width_cap, minf(movement_height_cap, pause_height_cap))))
    if edge < MIN_BUTTON_PX:
        return _invalid("viewport_too_small_for_touch_targets")

    var square: Vector2 = Vector2.ONE * edge
    var pitch: float = edge + GAP_PX
    var movement_origin: Vector2 = Vector2(
        usable.position.x + EDGE_PX,
        usable.end.y - EDGE_PX - 3.0 * edge - 2.0 * GAP_PX
    )
    var actions_origin: Vector2 = Vector2(
        usable.end.x - EDGE_PX - 2.0 * edge - GAP_PX,
        usable.end.y - EDGE_PX - 2.0 * edge - GAP_PX
    )
    var rects: Dictionary = {
        "move_forward": Rect2(movement_origin + Vector2(pitch, 0.0), square),
        "move_left": Rect2(movement_origin + Vector2(0.0, pitch), square),
        "move_right": Rect2(movement_origin + Vector2(2.0 * pitch, pitch), square),
        "move_back": Rect2(movement_origin + Vector2(pitch, 2.0 * pitch), square),
        "interact": Rect2(actions_origin + Vector2(pitch, 0.0), square),
        "sprint": Rect2(actions_origin + Vector2(0.0, pitch), square),
        "jump": Rect2(actions_origin + Vector2(pitch, pitch), square),
        "pause_game": Rect2(
            Vector2(usable.end.x - EDGE_PX - edge, usable.position.y + EDGE_PX),
            square
        )
    }
    # Fail closed if this layout is extended without maintaining eight
    # independent touch targets. Never return clipped or overlapping inputs.
    if rects.size() != ACTIONS.size():
        return _invalid("missing_action")
    for action in ACTIONS:
        if not rects.has(action):
            return _invalid("missing_action")
        var rect: Rect2 = rects[action]
        if not usable.encloses(rect):
            return _invalid("action_outside_safe_area")
    for i in range(ACTIONS.size()):
        var left: Rect2 = rects[ACTIONS[i]]
        for j in range(i + 1, ACTIONS.size()):
            var right: Rect2 = rects[ACTIONS[j]]
            if left.grow(2.0).intersects(right.grow(2.0)):
                return _invalid("overlapping_touch_targets")
    return {
        "ok": true,
        "safe_rect": usable,
        "button_size": square,
        "rects": rects
    }

static func _invalid(reason: String) -> Dictionary:
    return {"ok": false, "reason": reason, "rects": {}}
