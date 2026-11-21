class_name CivicMapDrivingPolicy
extends RefCounted
## MAP-002D: pure, UI-only map refresh and adaptive viewing rules.
## No physical movement, GPS authority, traffic, save or mission changes.
const MIN_RADIUS_M: float = 37.0
const MAX_RADIUS_M: float = 72.0
const SPEED_FULL_VIEW_MPS: float = 14.0
const ROUTE_REFRESH_M: float = 4.0
const MIN_DT_S: float = 0.035
const MAX_DT_S: float = 0.5

static func minimap_radius(speed_mps: float) -> float:
    if not is_finite(speed_mps):
        return MIN_RADIUS_M
    var ratio: float = clampf(maxf(0.0, speed_mps) / SPEED_FULL_VIEW_MPS, 0.0, 1.0)
    return lerpf(MIN_RADIUS_M, MAX_RADIUS_M, ratio)

## Reject time deltas that represent a pause or screen switch, avoiding
## minimap zoom spikes when input resumes after a background transition.
static func estimated_speed(previous: Vector3, current: Vector3,
        elapsed_s: float) -> float:
    if not previous.is_finite() or not current.is_finite() or (
            not is_finite(elapsed_s) or elapsed_s < MIN_DT_S or elapsed_s > MAX_DT_S):
        return 0.0
    var delta := Vector2(current.x - previous.x, current.z - previous.z)
    return clampf(delta.length() / elapsed_s, 0.0, 25.0)

static func should_refresh_route(previous: Vector3, current: Vector3,
        current_route: Dictionary, destination_changed: bool) -> bool:
    if destination_changed or not previous.is_finite() or not current.is_finite():
        return true
    if not bool(current_route.get("ok", false)):
        # A failed route stays failed until graph/destination changes.
        return false
    var moved: float = Vector2(current.x - previous.x,
        current.z - previous.z).length()
    if moved >= ROUTE_REFRESH_M:
        return true
    return false

static func draw_full_map(expanded: bool) -> bool:
    return expanded

## Minimap must remain low-noise if dense touch exclusions hide the
## launcher; no hidden surface needs redraw, even when GPS updates.
static func draw_minimap(expanded: bool, valid_size: bool) -> bool:
    return not expanded and valid_size
