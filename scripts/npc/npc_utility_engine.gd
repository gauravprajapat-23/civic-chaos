class_name CivicNpcUtilityEngine
extends RefCounted
## Pure deterministic NPC utility evaluator. No unsafe action can win scoring.

const ACTIONS := ["wait", "cross_legally", "help_person", "rush_crossing"]

static func choose(personality: CivicNpcPersonality, blackboard: CivicNpcBlackboard, seed: int = 0) -> Dictionary:
    if personality == null or blackboard == null or not personality.validate().is_empty() or blackboard.npc_id < 0:
        return {"ok": false, "action": "wait", "reason": "invalid_context"}
    var obs: Dictionary = blackboard.snapshot()["observations"]
    var urgency: float = clampf(float(obs.get("urgency", 0.0)), 0.0, 1.0)
    var pedestrian_green: bool = obs.get("pedestrian_green", false) == true
    var crossing_clear: bool = obs.get("crossing_clear", false) == true
    var person_needs_help: bool = obs.get("person_needs_help", false) == true
    var safe_to_help: bool = obs.get("safe_to_help", false) == true
    var scores: Dictionary = {}
    scores["wait"] = 0.3 + personality.patience * 0.6 - urgency * 0.2
    if pedestrian_green and crossing_clear:
        scores["cross_legally"] = 0.4 + urgency * 0.7 + personality.rule_compliance * 0.4
    if person_needs_help and safe_to_help:
        scores["help_person"] = 0.3 + personality.empathy * 0.9 - urgency * 0.15
    # Rush crossing is never permitted when the crossing is unsafe or red.
    if pedestrian_green and crossing_clear and urgency > 0.7:
        scores["rush_crossing"] = 0.1 + urgency * 0.5 + personality.aggression * 0.15
    var best_action := "wait"
    var best_score := -INF
    # Stable tie resolution by action order; seed only selects among exact ties.
    var tied: Array[String] = []
    for action in ACTIONS:
        if not scores.has(action):
            continue
        var score: float = scores[action]
        if score > best_score + 0.000001:
            best_score = score
            best_action = action
            tied = [action]
        elif absf(score - best_score) <= 0.000001:
            tied.append(action)
    if tied.size() > 1:
        var rng := RandomNumberGenerator.new()
        rng.seed = seed + blackboard.npc_id * 10007 + blackboard.tick_index
        best_action = tied[rng.randi_range(0, tied.size() - 1)]
    return {"ok": true, "action": best_action, "score": best_score, "scores": scores, "reason": "selected"}
