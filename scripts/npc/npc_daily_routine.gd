class_name CivicNpcDailyRoutine
extends RefCounted
## AI-03: deterministic, save-independent daily activity planning.
## Routines may delay sidewalk movement, but never grant crossing permission,
## teleport a pedestrian, resolve a civic incident, or modify civic scores.
const UTILITY = preload("res://scripts/npc/npc_utility_engine.gd")
const PERSONALITY = preload("res://scripts/npc/npc_personality.gd")
const BLACKBOARD = preload("res://scripts/npc/npc_blackboard.gd")

const CYCLE_TICKS: int = 4800
const ASSIST_CHECK_INTERVAL: int = 240

static func plan(slot: int, tick: int, incident_nearby: bool = false, safe_to_help: bool = false) -> Dictionary:
    if slot < 0 or tick < 0:
        return {"ok": false, "activity": "walk", "pause": false, "assist": false}
    # Stagger each pedestrian's day by a stable slot, not frame rate, RNG or
    # wall clock. The same (slot, tick, environment) always returns the same.
    var phase: int = posmod(tick + slot * 271, CYCLE_TICKS)
    var activity: String = "commute"
    var pause: bool = false
    if phase < 1800:
        activity = "commute"
    elif phase < 3000:
        activity = "market"
    elif phase < 3600:
        activity = "break"
        pause = true
    else:
        activity = "return_home"

    # Helping is only a voluntary, visual civic acknowledgement. It never
    # performs mission actions, awards points or overrides physical safety.
    var assist: bool = false
    if incident_nearby and safe_to_help and tick % ASSIST_CHECK_INTERVAL == 0:
        var person: CivicNpcPersonality = PERSONALITY.new() as CivicNpcPersonality
        person.patience = 0.0
        person.empathy = 1.0 if slot % 3 == 0 else 0.25
        var board: CivicNpcBlackboard = BLACKBOARD.new() as CivicNpcBlackboard
        if board.update_snapshot(slot, tick, {
            "person_needs_help": true, "safe_to_help": true, "urgency": 0.0
        }):
            var outcome: Dictionary = UTILITY.choose(person, board, 303)
            assist = bool(outcome.get("ok", false)) and str(outcome.get("action", "")) == "help_person"
    if assist:
        activity = "offer_help"
        pause = true
    return {"ok": true, "activity": activity, "pause": pause, "assist": assist}
