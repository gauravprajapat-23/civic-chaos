class_name CivicFollowingController
extends RefCounted
## Deterministic longitudinal gap control.

static func safe_speed(gap_m: float, lead_speed_mps: float, braking_mps2: float, minimum_gap_m: float, reaction_seconds: float) -> float:
    if not is_finite(gap_m) or not is_finite(lead_speed_mps) or braking_mps2 <= 0.0:
        return 0.0
    var free_space: float = maxf(0.0, gap_m - minimum_gap_m)
    var relative_limit: float = sqrt(braking_mps2 * braking_mps2 * reaction_seconds * reaction_seconds + 2.0 * braking_mps2 * free_space) - braking_mps2 * reaction_seconds
    return maxf(0.0, lead_speed_mps) + maxf(0.0, relative_limit)

static func permitted_travel(requested_m: float, gap_m: float, minimum_gap_m: float) -> float:
    if not is_finite(gap_m):
        return maxf(0.0, requested_m)
    return clampf(requested_m, 0.0, maxf(0.0, gap_m - minimum_gap_m))
