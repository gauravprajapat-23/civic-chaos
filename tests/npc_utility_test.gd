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
    assert(UtilityEngine.choose(personality, board)["action"] == "cross_legally")
    board.update_snapshot(1, 2, {"pedestrian_green": false, "crossing_clear": false, "urgency": 1.0})
    assert(UtilityEngine.choose(personality, board)["action"] == "wait")
    personality.empathy = 1.0
    board.update_snapshot(1, 3, {"person_needs_help": true, "safe_to_help": true, "urgency": 0.0})
    assert(UtilityEngine.choose(personality, board)["action"] == "help_person")
    board.update_snapshot(1, 4, {"person_needs_help": true, "safe_to_help": false, "urgency": 1.0})
    assert(not UtilityEngine.choose(personality, board)["scores"].has("help_person"))
    assert(UtilityEngine.choose(personality, board, 42) == UtilityEngine.choose(personality, board, 42))
    personality.aggression = 2.0
    assert(not UtilityEngine.choose(personality, board)["ok"])
    print("CIVIC_CHAOS_NPC_UTILITY_PASS")
    quit(0)
