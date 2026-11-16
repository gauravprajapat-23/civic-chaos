class_name CivicCityRoadLayout
extends RefCounted
## AUD2-MAP-01: shared longitudinal/transverse street axes.
## All driveable city-graph nodes must have a visible matching road strip.
## Coordinates are world metres, used by both the lane graph and district mesh.

const EXTENT_M: float = 120.0
const SECONDARY_M: float = 46.0
const ROAD_WIDTH_M: float = 8.0
const GRID_COORDINATES = [-EXTENT_M, -SECONDARY_M, 0.0, SECONDARY_M, EXTENT_M]

static func coordinates() -> Array[float]:
    # Return a copy so callers cannot mutate the layout definition.
    var result: Array[float] = []
    for coordinate in GRID_COORDINATES:
        result.append(float(coordinate))
    return result

static func is_perimeter_axis(coordinate: float) -> bool:
    return is_equal_approx(absf(coordinate), EXTENT_M)

static func road_span_m(width: float = ROAD_WIDTH_M) -> float:
    # A half-width extension past both endpoint nodes lets vehicles turn
    # within a paved intersection instead of driving off its road cap.
    return EXTENT_M * 2.0 + width

static func valid_district_dimensions(extent: float, width: float) -> bool:
    return is_equal_approx(extent, EXTENT_M) and is_equal_approx(width, ROAD_WIDTH_M)

## ROAD-FIX-01: non-overlapping walking/curb runs between cross streets.
## A full road opening plus turning clearance is removed at every node.
## The result is deterministic and shared by geometry and regression tests.
static func sidewalk_intervals(half_extent: float = EXTENT_M,
        crossing_half_width: float = ROAD_WIDTH_M * 0.5,
        turn_clearance: float = 1.5) -> Array[Vector2]:
    var spans: Array[Vector2] = []
    if not is_finite(half_extent) or not is_finite(crossing_half_width) or not is_finite(turn_clearance):
        return spans
    if half_extent <= 0.0 or crossing_half_width <= 0.0 or turn_clearance < 0.0:
        return spans
    var gap: float = crossing_half_width + turn_clearance
    var cursor: float = -half_extent
    for coordinate in coordinates():
        if coordinate < -half_extent or coordinate > half_extent:
            continue
        var start: float = maxf(-half_extent, coordinate - gap)
        if start - cursor > 0.02:
            spans.append(Vector2(cursor, start))
        cursor = maxf(cursor, minf(half_extent, coordinate + gap))
    if half_extent - cursor > 0.02:
        spans.append(Vector2(cursor, half_extent))
    return spans
