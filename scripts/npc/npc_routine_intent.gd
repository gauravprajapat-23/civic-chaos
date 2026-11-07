class_name CivicNPCRoutineIntent
extends RefCounted
## GAME-025-A2: pure-data intent arbitration for future route integration.
## Does not move an NPC, alter reservations, score events or choose coordinates.
## Existing traffic/collision authority always takes precedence.
const Routines = preload("res://scripts/npc/npc_daily_routines.gd")
const DESTINATION_AREAS: Dictionary = {
    "transit_stop": "transit",
    "workplace": "work",
    "residential_block": "residential",
    "market_stall": "market",
    "sanitation_depot": "municipal",
    "neighborhood_lane": "neighborhood",
    "community_square": "community"
}

static func area_for(destination: String) -> String:
    return str(DESTINATION_AREAS.get(destination, ""))

## Input flags are *observations* from the existing physics layer, never
## permission for a new routine to seize crossing ownership.
## A routine must not stop someone inside a crossing or while holding a
## reservation, even when the new agenda would otherwise be stationary.
static func decide(
        agent_id: int,
        at_tick: int,
        seed_value: int,
        in_crosswalk: bool,
        holds_reservation: bool,
        obstacle_ahead: bool,
        at_safe_destination: bool
    ) -> Dictionary:
    var agenda: Dictionary = Routines.agenda_for(agent_id, at_tick, seed_value)
    if agenda.is_empty():
        return {}
    var destination: String = str(agenda["destination"])
    var area: String = area_for(destination)
    if area.is_empty():
        return {}
    var mode: String = "walk_existing_route"
    var pause_allowed: bool = false
    var reason: String = "continue_current_route"
    if in_crosswalk or holds_reservation:
        # Keep current reservation/traffic controller as the only authority.
        # In particular, no "at work" idle pose can trap a reserved actor.
        mode = "crossing_authority"
        reason = "crossing_or_reservation_in_progress"
    elif obstacle_ahead:
        mode = "yield"
        pause_allowed = true
        reason = "physical_path_obstructed"
    elif bool(agenda["stationary"]) and at_safe_destination:
        mode = "perform_activity"
        pause_allowed = true
        reason = "safe_destination_reached"
    return {
        "id": agent_id,
        "role": str(agenda["role"]),
        "phase": str(agenda["phase"]),
        "activity": str(agenda["activity"]),
        "destination": destination,
        "area": area,
        "mode": mode,
        "pause_allowed": pause_allowed,
        "reason": reason,
        "path_authority": "existing_pedestrian_controller"
    }
