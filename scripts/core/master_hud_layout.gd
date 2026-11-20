class_name CivicMasterHudLayout
extends RefCounted
## MASTER-HUD-004: presentation-only live HUD composition.
## Source-of-truth touch rectangles come from the same joystick planner used
## by CivicTouchControls. No mission, traffic, or touch ownership mutation.
const TouchLayout = preload("res://scripts/ui/touch_layout.gd")
const SafeLayout = preload("res://scripts/ui/civic_hud_safe_layout.gd")
const Guide = preload("res://scripts/ui/civic_mission_guide.gd")
const Status = preload("res://scripts/ui/civic_status_hud.gd")

static func logical_safe_area(viewport: Vector2, display_safe: Rect2i,
        screen_pixels: Vector2i) -> Rect2:
    if not viewport.is_finite() or viewport.x <= 0.0 or viewport.y <= 0.0:
        return Rect2()
    if display_safe.size.x <= 0 or display_safe.size.y <= 0 or (
            screen_pixels.x <= 0 or screen_pixels.y <= 0):
        return Rect2()
    var scale := Vector2(viewport.x / float(screen_pixels.x),
        viewport.y / float(screen_pixels.y))
    return Rect2(Vector2(display_safe.position) * scale,
        Vector2(display_safe.size) * scale).intersection(Rect2(Vector2.ZERO, viewport))

static func plan(viewport: Vector2, safe: Rect2, touch_device: bool) -> Dictionary:
    var reserved: Array[Rect2] = []
    var usable: Rect2 = SafeLayout.usable(viewport, safe)
    if not usable.has_area():
        return {"safe": Rect2(), "map_reserved": reserved,
            "calls_reserved": reserved.duplicate(), "map_rect": Rect2(),
            "calls_rect": Rect2()}
    var guide: Rect2 = Guide.panel_bounds(viewport)
    var status: Rect2 = Status.layout_for(viewport)
    if guide.has_area():
        reserved.append(guide)
    if status.has_area():
        reserved.append(status)
    if touch_device:
        var touch: Dictionary = TouchLayout.joystick_plan(viewport, safe)
        if bool(touch.get("ok", false)):
            var center: Vector2 = touch["joystick_center"]
            var radius: float = float(touch["joystick_radius"]) * 1.4
            reserved.append(Rect2(center - Vector2.ONE * radius,
                Vector2.ONE * radius * 2.0))
            var rects: Dictionary = touch["rects"]
            for key in ["jump", "sprint", "interact", "pause_game"]:
                if rects.has(key):
                    reserved.append((rects[key] as Rect2).grow(8.0))
        else:
            # If touch geometry is invalid, never place launchers on an
            # unknown touch region. Desktop keyboard shortcuts remain intact.
            var blocked: Array[Rect2] = [usable]
            return {"safe": safe, "map_reserved": blocked,
                "calls_reserved": blocked.duplicate(), "map_rect": Rect2(),
                "calls_rect": Rect2()}
    var map_rect: Rect2 = SafeLayout.minimap(viewport, safe, reserved)
    var calls_reserved: Array[Rect2] = reserved.duplicate()
    if map_rect.has_area():
        calls_reserved.append(Rect2(map_rect.position,
            Vector2(map_rect.size.x, map_rect.size.y + 48.0)))
    var calls_rect: Rect2 = SafeLayout.launcher(viewport,
        Vector2(92, 48), safe, calls_reserved, true)
    return {"safe": safe, "map_reserved": reserved,
        "calls_reserved": calls_reserved, "map_rect": map_rect,
        "calls_rect": calls_rect}
