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

static func sustained_obstruction(diagnostics: Array[Dictionary]) -> bool:
    for record in diagnostics:
        if str(record.get("reason", "")) in [
                "lead_vehicle", "world_collider", "central_zone_occupied",
                "outer_zone_occupied", "outbound_blocked"]:
            if int(record.get("streak_ticks", 0)) >= MIN_BLOCKED_STREAK_TICKS:
                return true
    return false

static func eligible(pressure: Dictionary, diagnostics: Array[Dictionary],
        already_rewarded: bool) -> bool:
    return not already_rewarded and int(pressure.get("active", 0)) >= 3 and (
        int(pressure.get("stopped", 0)) >= 2 and sustained_obstruction(diagnostics))

static func verified(before_completed: int, after_completed: int,
        before_stopped: int, after_stopped: int) -> bool:
    return after_completed - before_completed >= REQUIRED_CLEARANCES and (
        after_stopped < before_stopped)
