class_name CivicTrafficStopDiagnostics
extends RefCounted
## ROAD-DIAG-02: pure read-only classification of *observed* holds.
## No changes to signals, stop line policy, car physics, rewards or saves.
const JAM_TICKS: int = 120
const LOG_INTERVAL_TICKS: int = 120

static func stop_reason(car: CivicVehicleAgent, observation_reason: String) -> String:
    if car == null or not car.active or car.speed_mps >= 0.2:
        return ""
    if car.last_physics_hold_reason != "":
        return car.last_physics_hold_reason
    if car.stop_requested:
        return "mission_hold"
    if observation_reason != "":
        return observation_reason
    if car.route.size() > 0 and car.current_route_index == car.route.size() - 1:
        var lane: CivicLaneData = car.road_graph.get_lane(car.route[car.current_route_index]) if car.road_graph != null else null
        if lane != null and lane.length_m() - car.lane_distance_m <= 0.15:
            return "route_end"
    return "unknown"

static func signal_reason(aspect: String, occupied: bool) -> String:
    if aspect != "green":
        return "red_signal"
    if occupied:
        return "crossing_occupied"
    return ""

static func outer_reason(reason: String) -> String:
    match reason:
        "red_or_clearance":
            return "red_signal"
        "zone_occupied":
            return "outer_zone_occupied"
        "higher_priority_approach", "higher_priority_lane", "higher_priority_slot":
            return "outer_priority"
    return ""

static func should_log(streak: int) -> bool:
    return streak >= JAM_TICKS and (streak - JAM_TICKS) % LOG_INTERVAL_TICKS == 0
