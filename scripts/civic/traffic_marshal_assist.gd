class_name CivicTrafficMarshalAssist
extends RefCounted
## ROAD-GAME-01. Pure evidence gates, not a traffic or score authority.
## Reward only if real cars finish their graph routes and stopped demand
## falls. An ordinary red-light queue does not qualify as an incident.
const REQUIRED_CLEARANCES: int = 2
const MIN_BLOCKED_STREAK_TICKS: int = 40
const METER_TICKS: int = 400 # 20 seconds at traffic's fixed 20 Hz
const REVIEW_TICKS: int = 800 # 40 seconds for measured recovery
const EVENT_ID: String = "traffic_marshal:center:verified_clearance"

static func center_obstruction_count(diagnostics: Array[Dictionary]) -> int:
    var count: int = 0
    for record in diagnostics:
        var position: Variant = record.get("position", null)
        if not (position is Vector3):
            continue
        var world_position: Vector3 = position
        if world_position.distance_to(Vector3.ZERO) > 18.0:
            continue
        if str(record.get("reason", "")) in [
                "lead_vehicle", "world_collider", "central_zone_occupied",
                "outer_zone_occupied", "outbound_blocked"]:
            if int(record.get("streak_ticks", 0)) >= MIN_BLOCKED_STREAK_TICKS:
                count += 1
    return count

static func sustained_obstruction(diagnostics: Array[Dictionary]) -> bool:
    return center_obstruction_count(diagnostics) >= 1

static func eligible(pressure: Dictionary, diagnostics: Array[Dictionary],
        already_rewarded: bool) -> bool:
    return not already_rewarded and int(pressure.get("active", 0)) >= 3 and (
        int(pressure.get("stopped", 0)) >= 2 and sustained_obstruction(diagnostics))

static func verified(before_completed: int, after_completed: int,
        before_stopped: int, after_stopped: int,
        before_center_blockers: int, after_center_blockers: int) -> bool:
    return after_completed - before_completed >= REQUIRED_CLEARANCES and (
        after_stopped < before_stopped) and before_center_blockers > 0 and (
        after_center_blockers < before_center_blockers)
