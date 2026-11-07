class_name CivicNPCRoutineWaypoints
extends RefCounted
## GAME-025-A3 gated draft. Logical stops are on EXISTING sidewalk lanes.
## Nothing here moves bodies, snaps them into position, or changes traffic.
const ROUTE_FRACTIONS: Dictionary = {
    "transit_stop": -0.40,
    "workplace": 0.38,
    "residential_block": -0.29,
    "market_stall": 0.29,
    "sanitation_depot": -0.36,
    "neighborhood_lane": 0.42,
    "community_square": 0.34
}
const MIN_JUNCTION_CLEARANCE: float = 8.0
const ARRIVAL_RADIUS: float = 0.45

static func target_progress(destination: String, district_extent: float, side: int) -> float:
    if not ROUTE_FRACTIONS.has(destination) or side < 0 or side > 3:
        return NAN
    if not is_finite(district_extent) or district_extent < 25.0 or district_extent > 200.0:
        return NAN
    var half_length: float = district_extent * 1.65 * 0.5
    var target: float = float(ROUTE_FRACTIONS[destination]) * half_length * 2.0
    # Slight lane staggering limits multiple occupations of the same stop.
    target += float(side) * 0.28 * (1.0 if target > 0.0 else -1.0)
    if absf(target) <= MIN_JUNCTION_CLEARANCE or absf(target) >= half_length - 1.0:
        return NAN
    return target

static func is_near_stop(progress: float, target: float, tolerance: float = ARRIVAL_RADIUS) -> bool:
    return is_finite(progress) and is_finite(target) and is_finite(tolerance) and tolerance > 0.0 and absf(progress - target) <= tolerance

static func is_safe_progress(progress: float, half_length: float) -> bool:
    return is_finite(progress) and is_finite(half_length) and half_length > MIN_JUNCTION_CLEARANCE + 2.0 and absf(progress) > MIN_JUNCTION_CLEARANCE and absf(progress) < half_length - 1.0
