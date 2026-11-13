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
