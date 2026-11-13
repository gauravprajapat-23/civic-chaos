extends SceneTree

const Personality = preload("res://scripts/npc/npc_personality.gd")
const Blackboard = preload("res://scripts/npc/npc_blackboard.gd")
const UtilityEngine = preload("res://scripts/npc/npc_utility_engine.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var personality := Personality.new()
    personality.rule_compliance = 1.0
    personality.patience = 0.0
    var board := Blackboard.new()
    board.update_snapshot(1, 1, {"pedestrian_green": true, "crossing_clear": true, "urgency": 0.4})
    if UtilityEngine.choose(personality, board).get("action") != "cross_legally":
        _fail("compliant NPC did not select a safe green crossing")
        return
    board.update_snapshot(1, 2, {"pedestrian_green": false, "crossing_clear": false, "urgency": 1.0})
    if UtilityEngine.choose(personality, board).get("action") != "wait":
        _fail("red or obstructed crossing failed to force a wait")
        return
    personality.empathy = 1.0
    board.update_snapshot(1, 3, {"person_needs_help": true, "safe_to_help": true, "urgency": 0.0})
    if UtilityEngine.choose(personality, board).get("action") != "help_person":
        _fail("high-empathy NPC did not help when safe")
        return
    board.update_snapshot(1, 4, {"person_needs_help": true, "safe_to_help": false, "urgency": 1.0})
    if UtilityEngine.choose(personality, board).get("scores", {}).has("help_person"):
        _fail("utility engine offered unsafe help")
        return
    if UtilityEngine.choose(personality, board, 42) != UtilityEngine.choose(personality, board, 42):
        _fail("NPC utility tie breaking is nondeterministic")
        return
    personality.aggression = 2.0
    if UtilityEngine.choose(personality, board).get("ok", true):
        _fail("out-of-bounds personality was not rejected")
        return
    print("CIVIC_CHAOS_NPC_UTILITY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
