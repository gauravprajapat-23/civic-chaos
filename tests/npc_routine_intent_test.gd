extends SceneTree
## GAME-025-A2: a daily routine may request activity, but cannot seize
## crossing authority or bypass the existing physics controller.
const Routines = preload("res://scripts/npc/npc_daily_routines.gd")
const Intent = preload("res://scripts/npc/npc_routine_intent.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var seed: int = Routines.DEFAULT_SEED
    for at_tick in [0, Routines.PHASE_TICKS, Routines.PHASE_TICKS * 2,
            Routines.PHASE_TICKS * 3, Routines.DAY_TICKS]:
        for index in range(16):
            var expected: Dictionary = Routines.agenda_for(index, at_tick, seed)
            var result: Dictionary = Intent.decide(index, at_tick, seed,
                false, false, false, false)
            if result.is_empty() or result["destination"] != expected["destination"]:
                _fail("intent dropped a deterministic destination")
                return
            if result["role"] != expected["role"] or result["phase"] != expected["phase"]:
                _fail("intent changed a role or day phase")
                return
            if result["area"] == "" or result["path_authority"] != "existing_pedestrian_controller":
                _fail("intent claimed its own physics controller or unknown area")
                return
            if result["mode"] != "walk_existing_route" or bool(result["pause_allowed"]):
                _fail("default intent must preserve existing pedestrian travel")
                return
            if Intent.decide(index, at_tick, seed,
                    false, false, false, false) != result:
                _fail("identical routine inputs gave different movement hints")
                return
            var crossing: Dictionary = Intent.decide(index, at_tick, seed,
                true, false, false, true)
            if crossing["mode"] != "crossing_authority" or bool(crossing["pause_allowed"]):
                _fail("routine stopped an NPC in a crosswalk")
                return
            var reserved: Dictionary = Intent.decide(index, at_tick, seed,
                false, true, false, true)
            if reserved["mode"] != "crossing_authority" or bool(reserved["pause_allowed"]):
                _fail("routine stopped a pedestrian holding a crossing reservation")
                return
            var blocked_crossing: Dictionary = Intent.decide(index, at_tick, seed,
                true, true, true, true)
            if blocked_crossing["mode"] != "crossing_authority":
                _fail("routine overrode crossing controller when the path was blocked")
                return
            var blocked: Dictionary = Intent.decide(index, at_tick, seed,
                false, false, true, false)
            if blocked["mode"] != "yield" or not bool(blocked["pause_allowed"]):
                _fail("routine ignored a blocked pedestrian path")
                return
            var arrived: Dictionary = Intent.decide(index, at_tick, seed,
                false, false, false, true)
            if bool(expected["stationary"]):
                if arrived["mode"] != "perform_activity" or not bool(arrived["pause_allowed"]):
                    _fail("stationary NPC did not receive safe activity intent")
                    return
            elif arrived["mode"] != "walk_existing_route":
                _fail("routine froze a roaming pedestrian at an arbitrary destination")
                return
    if not Intent.decide(-1, 0, seed, false, false, false, false).is_empty():
        _fail("unknown pedestrian identity produced a routine intent")
        return
    if not Intent.decide(0, -1, seed, false, false, false, false).is_empty():
        _fail("negative district time produced an intent")
        return
    if not Intent.decide(0, 0, -1, false, false, false, false).is_empty():
        _fail("invalid seed produced an intent")
        return
    if Intent.area_for("unmapped_location") != "":
        _fail("a nonexistent area was treated as a valid destination")
        return
    print("CIVIC_CHAOS_NPC_ROUTINE_INTENT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
