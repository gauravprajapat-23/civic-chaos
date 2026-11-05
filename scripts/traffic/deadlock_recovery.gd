class_name CivicDeadlockRecovery
extends RefCounted
## Plans deterministic recovery; never forces movement or releases occupied zones.

var detector: CivicDeadlockDetector
var reservations: CivicIntersectionReservations
var router: CivicLaneRouter
var attempts: Dictionary = {}
var maximum_attempts: int = 3

func configure(wait_detector: CivicDeadlockDetector, zone_manager: CivicIntersectionReservations, lane_router: CivicLaneRouter) -> bool:
    if wait_detector == null or zone_manager == null or lane_router == null or lane_router.graph == null:
        return false
    detector = wait_detector
    reservations = zone_manager
    router = lane_router
    return true

func plan_recovery(cycle: PackedInt32Array, positions: Dictionary, destinations: Dictionary, vehicle_mask: int, blocked_lanes: PackedInt32Array = PackedInt32Array()) -> Dictionary:
    if detector == null or reservations == null or router == null or cycle.size() < 2 or vehicle_mask <= 0:
        return _failed("invalid_context")
    var normalized := cycle.duplicate()
    normalized.sort()
    var active := false
    for detected in detector.detect_cycles():
        if detected == normalized:
            active = true
            break
    if not active:
        return _failed("cycle_not_confirmed")
    for id in normalized:
        if not positions.has(id) or not destinations.has(id):
            return _failed("missing_route_context")
    # Deterministic candidate order; occupied reservations are never released.
    for id in normalized:
        var tries: int = int(attempts.get(id, 0))
        if tries >= maximum_attempts:
            continue
        var start: int = int(positions[id])
        var goal: int = int(destinations[id])
        var blocked := blocked_lanes.duplicate()
        for other in normalized:
            if other != id and positions.has(other):
                var lane: int = int(positions[other])
                if not blocked.has(lane):
                    blocked.append(lane)
        var route := router.find_route(start, goal, vehicle_mask, blocked)
        attempts[id] = tries + 1
        if route["ok"] and (route["path"] as PackedInt32Array).size() > 1:
            # Route is a proposal. Caller must check physical clearance and request
            # fresh reservations before moving; do not clear wait edges yet.
            return {"ok": true, "action": "replan", "vehicle_id": id, "route": route["path"], "reason": "safe_route_candidate"}
    return _failed("no_safe_route")

func repair_stale_reservation(vehicle_id: int, zone: String) -> bool:
    if reservations == null or vehicle_id < 0 or zone.is_empty():
        return false
    # Never cancel an occupant's reservation; cancellation cannot evict occupants.
    if reservations.occupant(zone) != -1:
        return false
    reservations.cancel(vehicle_id)
    return true

func acknowledge_recovery(vehicle_id: int) -> void:
    if detector != null:
        detector.clear_wait(vehicle_id)
    attempts.erase(vehicle_id)

func _failed(reason: String) -> Dictionary:
    return {"ok": false, "action": "hold", "vehicle_id": -1, "route": PackedInt32Array(), "reason": reason}
