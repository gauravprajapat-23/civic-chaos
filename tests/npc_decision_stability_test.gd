extends SceneTree
## AI-01: opt-in utility hysteresis; this does not move district NPCs.
## Replay and safety must stay deterministic before GAME-025 integration.
const Personality = preload("res://scripts/npc/npc_personality.gd")
const Blackboard = preload("res://scripts/npc/npc_blackboard.gd")
const Stability = preload("res://scripts/npc/npc_decision_stability.gd")
const Pedestrians = preload("res://scripts/npc/district_pedestrians.gd")
const DailyRoutine = preload("res://scripts/npc/npc_daily_routine.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if not _test_near_ties_and_safety():
        return
    if not _test_help_safety_and_invalid_inputs():
        return
    if not _test_snapshot_and_replay():
        return
    if not _test_physical_crossing_adapter():
        return
    if not _test_daily_routine_and_safe_assistance():
        return
    print("CIVIC_CHAOS_NPC_DECISION_STABILITY_PASS")
    quit(0)

func _test_near_ties_and_safety() -> bool:
    var personality := Personality.new()
    personality.patience = 1.0
    personality.rule_compliance = 0.0
    var board := Blackboard.new()
    var stable: CivicNpcDecisionStability = Stability.new() as CivicNpcDecisionStability
    if not board.update_snapshot(10, 0, {"pedestrian_green": true, "crossing_clear": true, "urgency": 0.52}):
        return _fail("could not initialize NPC blackboard")
    if stable.decide(personality, board, 99).get("action") != "wait":
        return _fail("near-tie baseline should initially wait")
    var changes: int = 0
    for tick in range(1, 121):
        var urgency: float = 0.59 if tick % 2 == 0 else 0.52
        if not board.update_snapshot(10, tick, {"pedestrian_green": true, "crossing_clear": true, "urgency": urgency}):
            return _fail("could not update near-tie observations")
        var result: Dictionary = stable.decide(personality, board, 99)
        if result.get("action") != "wait" or not bool(result.get("ok", false)):
            return _fail("NPC jittered between near-tied decisions at tick " + str(tick))
        changes += 1 if bool(result.get("changed", false)) else 0
    if changes != 0:
        return _fail("near-tie action changes were not suppressed")
    board.update_snapshot(10, 121, {"pedestrian_green": true, "crossing_clear": true, "urgency": 1.0})
    var switching: Dictionary = stable.decide(personality, board, 99)
    if switching.get("action") != "cross_legally" or switching.get("reason") != "stronger_action":
        return _fail("stronger legal action did not overcome hysteresis after hold")

    # Safety is evaluated again even if observation changes in the same tick.
    board.update_snapshot(10, 121, {"pedestrian_green": false, "crossing_clear": true, "urgency": 1.0})
    var red: Dictionary = stable.decide(personality, board, 99)
    if red.get("action") != "wait" or red.get("reason") != "safety_override":
        return _fail("red signal failed to interrupt a held crossing immediately")
    board.update_snapshot(10, 122, {"pedestrian_green": true, "crossing_clear": true, "urgency": 1.0})
    var still_waiting: Dictionary = stable.decide(personality, board, 99)
    if still_waiting.get("action") != "wait" or still_waiting.get("reason") != "minimum_hold":
        return _fail("the cool-down did not prevent an immediate bounce-back")
    board.update_snapshot(10, 127, {"pedestrian_green": true, "crossing_clear": true, "urgency": 1.0})
    if stable.decide(personality, board, 99).get("action") != "cross_legally":
        return _fail("strong action could not resume after hold expired")

    # A new NPC cannot inherit another agent's action/cooldown by accident.
    var foreign := Blackboard.new()
    foreign.update_snapshot(11, 128, {"pedestrian_green": false, "crossing_clear": false})
    if stable.decide(personality, foreign, 99).get("ok", true):
        return _fail("another NPC reused an unrelated decision history")
    if stable.snapshot()["npc_id"] != 10:
        return _fail("foreign NPC corrupted the current agent identity")
    return true

func _test_help_safety_and_invalid_inputs() -> bool:
    var personality := Personality.new()
    personality.empathy = 1.0
    personality.patience = 0.0
    var board := Blackboard.new()
    var stable: CivicNpcDecisionStability = Stability.new() as CivicNpcDecisionStability
    board.update_snapshot(20, 1, {"person_needs_help": true, "safe_to_help": true, "urgency": 0.0})
    if stable.decide(personality, board).get("action") != "help_person":
        return _fail("empathetic NPC did not select safe assistance")
    board.update_snapshot(20, 1, {"person_needs_help": true, "safe_to_help": false, "urgency": 0.0})
    if stable.decide(personality, board).get("action") != "wait":
        return _fail("unsafe help persisted because of decision inertia")
    for invalid in [
        {"urgency": "high"}, {"urgency": -0.2},
        {"pedestrian_green": "yes"}
    ]:
        if not board.update_snapshot(20, 2, invalid):
            return _fail("test fixture wrongly rejected JSON-safe invalid utility observation")
        if stable.decide(personality, board).get("ok", true):
            return _fail("invalid observation was accepted: " + str(invalid))
    # The blackboard itself must reject nonfinite observations.
    for invalid in [{"urgency": INF}, {"social_influence": NAN}]:
        if board.update_snapshot(20, 2, invalid):
            return _fail("nonfinite blackboard observation was accepted")

    # Validation should fail without advancing the decision clock or dropping state.
    var state: Dictionary = stable.snapshot()
    var old_board := Blackboard.new()
    old_board.update_snapshot(20, 0, {"urgency": 0.1})
    if stable.decide(personality, old_board).get("ok", true):
        return _fail("stale blackboard tick was accepted")
    if stable.snapshot() != state:
        return _fail("invalid input modified persisted policy state")
    stable.reset()
    if stable.snapshot()["npc_id"] != -1:
        return _fail("reset did not clear previous NPC identity")
    return true

func _test_snapshot_and_replay() -> bool:
    var personality := Personality.new()
    personality.patience = 1.0
    personality.rule_compliance = 0.0
    var board := Blackboard.new()
    var first: CivicNpcDecisionStability = Stability.new() as CivicNpcDecisionStability
    var second: CivicNpcDecisionStability = Stability.new() as CivicNpcDecisionStability
    var trace_a: Array[String] = []
    var trace_b: Array[String] = []
    for tick in range(0, 40):
        var obs: Dictionary = {"pedestrian_green": true,
            "crossing_clear": tick % 9 != 0, "urgency": 0.52 + (0.07 if tick % 2 == 0 else 0.0)}
        board.update_snapshot(33, tick, obs)
        var a: Dictionary = first.decide(personality, board, 2026)
        var b: Dictionary = second.decide(personality, board, 2026)
        if a != b:
            return _fail("identical seed and blackboard produced different results")
        trace_a.append(str(a.get("action", "")))
        trace_b.append(str(b.get("action", "")))
    if trace_a != trace_b:
        return _fail("fixed-tick decisions did not replay identically")
    var captured: Dictionary = first.snapshot()
    var restored: CivicNpcDecisionStability = Stability.new() as CivicNpcDecisionStability
    var json: Variant = JSON.parse_string(JSON.stringify(captured))
    if not restored.restore(json) or restored.snapshot() != captured:
        return _fail("policy state did not survive JSON serialization")
    var bad: Dictionary = captured.duplicate(true)
    bad["last_switch_tick"] = int(captured["last_tick"]) + 1
    if restored.restore(bad) or restored.snapshot() != captured:
        return _fail("invalid future switch tick damaged the previous policy")
    bad = captured.duplicate(true)
    bad["current_action"] = "ignore_red_light"
    if restored.restore(bad):
        return _fail("unknown action entered saved policy state")
    board.update_snapshot(33, 40, {"pedestrian_green": false, "crossing_clear": false})
    if restored.decide(personality, board, 2026) != first.decide(personality, board, 2026):
        return _fail("restored agent diverged from same fixed-tick source state")
    print("CIVIC_CHAOS_REPLAY_STATE npc_stability=" + JSON.stringify(trace_a))
    return true

## AI-02: isolated real pedestrian adapter. Even with utility AI enabled,
## physical red/occupied crossing safety is a hard veto; hysteresis may only
## delay the next legal entrance. Disabled behavior stays unchanged.
func _test_physical_crossing_adapter() -> bool:
    var stage := Node3D.new()
    root.add_child(stage)
    var walkers := Pedestrians.new()
    walkers.pedestrian_count = 1
    walkers.set_physics_process(false)
    stage.add_child(walkers)
    if walkers.checkpoint_state()["walkers"].size() != 1:
        return _fail("stable crossing fixture did not stage one pedestrian")
    var before: Dictionary = walkers.checkpoint_state()
    if not walkers.crossing_decision(0, true):
        return _fail("opt-in disabled crossing changed legacy permission")
    walkers.stable_crossing_decisions_enabled = true
    walkers._decision_tick = 10
    if not walkers.crossing_decision(0, true):
        return _fail("safe utility crossing was not permitted")
    if walkers.crossing_decision(0, false):
        return _fail("utility AI crossed an unsafe road")
    walkers._decision_tick = 11
    if walkers.crossing_decision(0, true):
        return _fail("crossing cooldown failed to prevent immediate flip")
    walkers._decision_tick = 17
    if not walkers.crossing_decision(0, true):
        return _fail("stable policy could not resume legal crossing")
    if walkers.crossing_decision(-1, true) or walkers.crossing_decision(5, true):
        return _fail("invalid walker index bypassed crossing policy")
    if walkers.checkpoint_state() != before:
        return _fail("utility decision modified v1 pedestrian checkpoint data")
    walkers.reset_crossing_decisions()
    walkers._decision_tick = 0
    if not walkers.crossing_decision(0, true):
        return _fail("policy reset retained prior crossing inertia")
    stage.queue_free()
    return true

## AI-03: deterministic activity slots, conditional civic assistance and
## physical walker opt-in must not mutate the GAME-024 checkpoint.
func _test_daily_routine_and_safe_assistance() -> bool:
    var morning: Dictionary = DailyRoutine.plan(0, 0)
    var market: Dictionary = DailyRoutine.plan(0, 1800)
    var break_time: Dictionary = DailyRoutine.plan(0, 3000)
    var home: Dictionary = DailyRoutine.plan(0, 3600)
    if morning.get("activity") != "commute" or market.get("activity") != "market":
        return _fail("routine did not follow scheduled morning/market phases")
    if break_time.get("activity") != "break" or not break_time.get("pause", false):
        return _fail("routine did not provide a scheduled sidewalk break")
    if home.get("activity") != "return_home" or home.get("pause", true):
        return _fail("routine did not resume returning home")
    if DailyRoutine.plan(0, 3000) != break_time:
        return _fail("routine planner was not deterministic")
    if DailyRoutine.plan(-1, 0).get("ok", true):
        return _fail("routine planner accepted a negative walker identity")
    var helpful: Dictionary = DailyRoutine.plan(0, 240, true, true)
    if not helpful.get("assist", false) or helpful.get("activity") != "offer_help":
        return _fail("empathetic NPC did not offer a safe civic reaction")
    if DailyRoutine.plan(0, 240, true, false).get("assist", true):
        return _fail("assistance ignored an unsafe real-world context")
    if DailyRoutine.plan(0, 241, true, true).get("assist", true):
        return _fail("civic assistance did not respect its fixed tick interval")
    if DailyRoutine.plan(1, 240, true, true).get("assist", true):
        return _fail("different NPC personalities did not change helping behavior")
    var stage := Node3D.new()
    root.add_child(stage)
    var walkers := Pedestrians.new()
    walkers.pedestrian_count = 1
    walkers.set_physics_process(false)
    stage.add_child(walkers)
    if walkers._walkers.size() != 1:
        return _fail("routine fixture has no physical pedestrian")
    var saved: Dictionary = walkers.checkpoint_state()
    if walkers._routine_rest_at_safe_sidewalk(0, 0):
        return _fail("disabled AI routine unexpectedly paused a pedestrian")
    walkers.daily_routines_enabled = true
    walkers._decision_tick = 3000
    if not walkers._routine_rest_at_safe_sidewalk(0, 0):
        return _fail("opt-in routine did not pause a safe sidewalk walker")
    if walkers.routine_activity(0) != "break":
        return _fail("routine activity was not exposed to presentation")
    if walkers.checkpoint_state() != saved:
        return _fail("visual routine changed the existing pedestrian save schema")
    # Planned rest is not a collision stall: repeated physics ticks must
    # reset the obstruction counter instead of accumulating false blockage.
    walkers._blocked_frames[0] = 17
    walkers._physics_process(0.016)
    if walkers._blocked_frames[0] != 0:
        return _fail("scheduled sidewalk rest was counted as collision blockage")
    # A nearby player is not a license to offer help within overlapping
    # actors, even if an active civic incident exists in the same area.
    var volunteer := Node3D.new()
    volunteer.name = "PlayerRoot"
    stage.add_child(volunteer)
    volunteer.global_position = walkers._walkers[0]["root"].global_position
    if walkers._routine_help_is_clear(0):
        return _fail("civic helper ignored an overlapping player")
    volunteer.queue_free()
    stage.queue_free()
    return true

func _fail(reason: String) -> bool:
    push_error(reason)
    quit(1)
    return false
