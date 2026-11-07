extends SceneTree

const Personality = preload("res://scripts/npc/npc_personality.gd")
const Blackboard = preload("res://scripts/npc/npc_blackboard.gd")
const UtilityEngine = preload("res://scripts/npc/npc_utility_engine.gd")
const Influence = preload("res://scripts/npc/social_influence.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var positive: Array = []
    var negative: Array = []
    for i in range(20):
        positive.append({"kind": "waited_for_green", "proximity": 1.0})
        negative.append({"kind": "ignored_signal", "proximity": 1.0})
    assert(Influence.calculate(positive, 1.0) == 1.0)
    assert(Influence.calculate(negative, 1.0) == -1.0)
    assert(Influence.calculate(positive, 0.0) == 0.0)
    assert(Influence.calculate(positive, 0.5) == Influence.calculate(positive, 0.5))
    var person := Personality.new()
    person.rule_compliance = 0.5
    person.patience = 0.5
    var board := Blackboard.new()
    assert(board.update_snapshot(9, 1, Influence.apply_to_observations({"pedestrian_green": false, "crossing_clear": false}, negative, 1.0)))
    var result := UtilityEngine.choose(person, board, 7)
    assert(result["action"] == "wait")
    assert(not result["scores"].has("cross_legally"))
    assert(not result["scores"].has("rush_crossing"))
    assert(board.update_snapshot(9, 2, Influence.apply_to_observations({"pedestrian_green": true, "crossing_clear": true}, positive, 1.0)))
    var encouraged := UtilityEngine.choose(person, board, 7)
    assert(encouraged["scores"]["cross_legally"] > 0.0)
    print("CIVIC_CHAOS_SOCIAL_INFLUENCE_PASS")
    quit(0)
