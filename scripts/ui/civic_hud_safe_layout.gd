class_name CivicHudSafeLayout
extends RefCounted
## UI-003 — presentation-only safe viewport and non-overlapping HUD geometry.
## Safe area coordinates and reserved rectangles use viewport logical pixels.
## No gameplay, mission, reward, or touch ownership state lives here.
const EDGE_MARGIN: float = 8.0
const MIN_TAP: float = 44.0

static func usable(viewport: Vector2, safe_area: Rect2 = Rect2()) -> Rect2:
    if not viewport.is_finite() or viewport.x <= 0.0 or viewport.y <= 0.0:
        return Rect2()
    var screen := Rect2(Vector2.ZERO, viewport)
    if safe_area.size.x <= 0.0 or safe_area.size.y <= 0.0:
        return screen
    return screen.intersection(safe_area)

static func inset(area: Rect2, amount: float = EDGE_MARGIN) -> Rect2:
    if area.size.x <= 0.0 or area.size.y <= 0.0:
        return Rect2()
    var gap: float = minf(amount, minf(area.size.x, area.size.y) * 0.25)
    return Rect2(area.position + Vector2.ONE * gap,
        area.size - Vector2.ONE * gap * 2.0)

static func intersects_reserved(rect: Rect2, exclusions: Array[Rect2]) -> bool:
    for item in exclusions:
        if item.size.x > 0.0 and item.size.y > 0.0 and rect.intersects(item):
            return true
    return false

## Find a safe launcher from a deterministic set of locations on the same
## side of the screen. On a dense 320px device, shrink rather than overlap.
static func launcher(viewport: Vector2, desired: Vector2, safe_area: Rect2 = Rect2(),
        exclusions: Array[Rect2] = [], right_aligned: bool = true) -> Rect2:
    var area: Rect2 = inset(usable(viewport, safe_area))
    if area.size.x <= 0.0 or area.size.y <= 0.0:
        return Rect2()
    var size := Vector2(minf(desired.x, area.size.x), minf(desired.y, area.size.y))
    var x: float = area.end.x - size.x if right_aligned else area.position.x
    var slots: Array[float] = [0.55, 0.42, 0.28, 0.70, 0.12, 0.85, 0.0, 1.0]
    for fraction in slots:
        var y: float = area.position.y + (area.size.y - size.y) * fraction
        var candidate := Rect2(Vector2(x, y), size)
        if not intersects_reserved(candidate, exclusions):
            return candidate
    # Dense exclusion layouts cannot guarantee a safe launcher. Hide it
    # rather than cover joystick, action keys, or a critical mission panel.
    return Rect2()

static func panel(viewport: Vector2, max_size: Vector2, safe_area: Rect2 = Rect2()) -> Rect2:
    var area: Rect2 = inset(usable(viewport, safe_area))
    if area.size.x <= 0.0 or area.size.y <= 0.0:
        return Rect2()
    var size := Vector2(minf(max_size.x, area.size.x), minf(max_size.y, area.size.y))
    return Rect2(area.position + (area.size - size) * 0.5, size)

## The minimap and its launcher form a single occupied rectangle. Place
## them above touch controls and within cutouts; return empty if impossible.
static func minimap(viewport: Vector2, safe_area: Rect2 = Rect2(),
        exclusions: Array[Rect2] = []) -> Rect2:
    var area: Rect2 = inset(usable(viewport, safe_area))
    if area.size.x < 96.0 or area.size.y < 160.0:
        return Rect2()
    var size: float = minf(156.0, maxf(88.0,
        minf(area.size.x * 0.29, area.size.y * 0.25)))
    size = minf(size, area.size.x)
    var launcher_height: float = 44.0
    var total_height: float = size + 4.0 + launcher_height
    if total_height > area.size.y:
        return Rect2()
    var x: float = area.position.x
    for fraction in [0.75, 0.60, 0.45, 0.30, 0.15, 0.0]:
        var y: float = area.position.y + (area.size.y - total_height) * fraction
        var square := Rect2(Vector2(x, y), Vector2.ONE * size)
        var occupied := Rect2(square.position, Vector2(size, total_height))
        if not intersects_reserved(occupied, exclusions):
            return square
    return Rect2()
