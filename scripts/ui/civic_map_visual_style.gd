class_name CivicMapVisualStyle
extends RefCounted
## MAP-002A: purely visual, deterministic cartographic styling.
## No new road geometry, positions, routes, traffic classes or save data.
const BACKGROUND := Color(0.055, 0.080, 0.102, 0.98)
const PANEL_EDGE := Color(0.22, 0.32, 0.38)
const BLOCK_TINT := Color(0.095, 0.139, 0.16, 0.95)
const MARKET_ROAD := Color(0.89, 0.82, 0.69)
const COLLECTOR_ROAD := Color(0.58, 0.68, 0.70)
const MARKET_EDGE := Color(0.29, 0.31, 0.34)
const COLLECTOR_EDGE := Color(0.17, 0.26, 0.29)
const ROUTE_HALO := Color(0.025, 0.09, 0.10)
const ROUTE := Color(0.25, 0.96, 0.71)
const PLAYER := Color(0.19, 0.83, 1.0)

## Road classes are only those grounded in the canonical city network.
## We never infer fictitious highways from the old rectangular coordinates.
static func road_rank(road: Dictionary) -> int:
    return 2 if str(road.get("road_type", "")) == "market" else 1

static func road_width(road: Dictionary, pixels_per_meter: float,
        mini: bool) -> float:
    var physical: float = maxf(1.0, float(road.get("width_m", 1.0)))
    var rank: int = road_rank(road)
    var emphasis: float = 1.14 if rank == 2 else 0.78
    var min_stroke: float = 3.8 if mini and rank == 2 else (
        2.8 if mini else (4.0 if rank == 2 else 2.6))
    return clampf(physical * pixels_per_meter * emphasis, min_stroke,
        19.0 if mini else 32.0)

static func road_color(road: Dictionary) -> Color:
    return MARKET_ROAD if road_rank(road) == 2 else COLLECTOR_ROAD

static func road_edge(road: Dictionary) -> Color:
    return MARKET_EDGE if road_rank(road) == 2 else COLLECTOR_EDGE

## Reject entirely offscreen segments (with a stroke-width gutter).
## Does not modify the endpoints of curved centerline segments.
static func segment_visible(a: Vector2, b: Vector2, area: Rect2,
        gutter: float = 12.0) -> bool:
    if not a.is_finite() or not b.is_finite() or not area.has_area():
        return false
    var bounds := area.grow(maxf(0.0, gutter))
    return maxf(a.x, b.x) >= bounds.position.x and (
        minf(a.x, b.x) <= bounds.end.x) and (
        maxf(a.y, b.y) >= bounds.position.y) and (
        minf(a.y, b.y) <= bounds.end.y)

## Marker orientation: minimap heading is fixed upward, full-map player
## arrow follows the real world heading (world -Z is north).
static func player_triangle(position: Vector2, heading: Vector2,
        radius: float) -> PackedVector2Array:
    var forward := heading.normalized() if heading.length_squared() > 0.00001 else Vector2.UP
    var side := Vector2(-forward.y, forward.x)
    return PackedVector2Array([
        position + forward * radius,
        position - forward * radius * 0.62 + side * radius * 0.65,
        position - forward * radius * 0.62 - side * radius * 0.65
    ])

static func frame_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = BACKGROUND
    style.border_color = PANEL_EDGE
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    style.set_content_margin_all(0)
    return style
