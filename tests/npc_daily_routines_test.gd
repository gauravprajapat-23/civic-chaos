extends SceneTree
## GAME-025-A draft regression: deterministic roles, day changes, JSON and forgery.
const Routines = preload("res://scripts/npc/npc_daily_routines.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var a := Routines.new() as CivicNPCRoutines
    var b := Routines.new() as CivicNPCRoutines
    if not a.configure(8) or not b.configure(8) or a.configure(8):
        _fail("routine planner accepted duplicate configure or failed initial setup")
        return
    if a.agent_state(0).is_empty() or not a.agent_state(8).is_empty():
        _fail("pedestrian IDs are not bounded by the configured population")
        return
    var all_roles: Dictionary = {}
    for index in range(8):
        var profile: Dictionary = a.agent_state(index)
        all_roles[str(profile["role"])] = true
        if profile["phase"] != "morning" or profile["activity"] == "" or profile["destination"] == "":
            _fail("initial schedule missing role, phase, activity or destination")
            return
    if all_roles.size() != 4:
        _fail("role assignment did not provide commuter, shopkeeper, sanitation and resident")
        return
    for value in [1, 299, 300, 599, 600, 899, 900, 1199, 1200, 2400]:
        if not a.advance_to(value) or not b.advance_to(value):
            _fail("could not advance deterministic simulated district clock")
            return
        if a.checkpoint_state() != b.checkpoint_state():
            _fail("identical seeded schedules diverged")
            return
        var phase: String = a.agent_state(0)["phase"]
        if phase != Routines.phase_for_tick(value):
            _fail("phase changed at an incorrect simulated district tick")
            return
    if Routines.phase_for_tick(300) != "workday" or Routines.phase_for_tick(600) != "evening" or Routines.phase_for_tick(900) != "night" or Routines.phase_for_tick(1200) != "morning":
        _fail("daily cycle missed a boundary")
        return
    var saved: Variant = JSON.parse_string(JSON.stringify(a.checkpoint_state()))
    if not a.checkpoint_valid(saved):
        _fail("valid JSON agenda checkpoint refused")
        return
    var restored := Routines.new() as CivicNPCRoutines
    if not restored.configure(8) or not restored.restore_checkpoint(saved):
        _fail("daily agenda failed new-world restore")
        return
    if restored.checkpoint_state() != a.checkpoint_state():
        _fail("restored agenda changed roles, times or destinations")
        return
    if restored.advance_to(2399):
        _fail("stale simulated day tick was accepted")
        return
    var baseline: Dictionary = restored.checkpoint_state()
    var tampered: Dictionary = (saved as Dictionary).duplicate(true)
    tampered["agents"][0]["role"] = "municipal_vip"
    if restored.restore_checkpoint(tampered):
        _fail("forged walker role accepted")
        return
    tampered = (saved as Dictionary).duplicate(true)
    tampered["agents"][0]["destination"] = "highway"
    if restored.restore_checkpoint(tampered):
        _fail("forged schedule destination accepted")
        return
    tampered = (saved as Dictionary).duplicate(true)
    tampered["agents"][0]["id"] = 4
    if restored.restore_checkpoint(tampered):
        _fail("duplicate walker identity accepted")
        return
    tampered = (saved as Dictionary).duplicate(true)
    tampered["tick"] = -1
    if restored.restore_checkpoint(tampered):
        _fail("negative simulated day tick accepted")
        return
    tampered = (saved as Dictionary).duplicate(true)
    tampered["agent_count"] = 10
    if restored.restore_checkpoint(tampered):
        _fail("forged pedestrian population accepted")
        return
    if restored.checkpoint_state() != baseline:
        _fail("rejected checkpoint changed live schedule state")
        return
    print("CIVIC_CHAOS_NPC_DAILY_ROUTINES_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
