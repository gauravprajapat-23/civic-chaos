class_name CivicTrafficSensor
extends RefCounted
## Finds nearest preceding agent on the same directed lane.
## Input is sorted by stable instance ID for deterministic tie-breaking.

static func nearest_lead(follower: CivicVehicleAgent, vehicles: Array[CivicVehicleAgent], obstacles: Array[Dictionary] = []) -> Dictionary:
    if follower == null or not follower.active:
        return {"detected": false}
    var lane_id: int = follower.route[follower.current_route_index]
    var best_gap: float = INF
    var best_speed: float = 0.0
    var best_id: int = 2147483647
    for candidate in vehicles:
        if candidate == null or candidate == follower or not candidate.active or candidate.route.is_empty():
            continue
        if candidate.route[candidate.current_route_index] != lane_id:
            continue
        var gap: float = candidate.lane_distance_m - follower.lane_distance_m
        var id: int = candidate.get_instance_id()
        if gap >= 0.0 and (gap < best_gap or (is_equal_approx(gap, best_gap) and id < best_id)):
            best_gap = gap
            best_speed = candidate.speed_mps
            best_id = id
    for obstacle in obstacles:
        if int(obstacle.get("lane_id", -1)) != lane_id:
            continue
        var gap: float = float(obstacle.get("distance_m", -INF)) - follower.lane_distance_m
        if gap >= 0.0 and gap < best_gap:
            best_gap = gap
            best_speed = 0.0
            best_id = -1
    if not is_finite(best_gap):
        return {"detected": false}
    return {"detected": true, "gap_m": best_gap, "lead_speed_mps": best_speed, "object_id": best_id}
