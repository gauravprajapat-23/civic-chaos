class_name CivicAiLodScheduler
extends RefCounted
## Deterministic fixed-tick scheduling of expensive NPC decisions.
## Movement, collisions and reservation updates must run every simulation tick.

enum Tier { NEAR, MIDDLE, FAR }
const INTERVALS := [1, 4, 20]
var near_radius_m: float = 25.0
var middle_radius_m: float = 80.0
var agents: Dictionary = {}
var _last_tick: int = -1
var _counts: Dictionary = {0: 0, 1: 0, 2: 0}

func register_agent(id: int, distance_m: float) -> bool:
    if id < 0 or not is_finite(distance_m) or distance_m < 0.0:
        return false
    agents[id] = {"tier": _tier_for(distance_m), "last_decision_tick": -1, "decision_count": 0}
    return true

func unregister_agent(id: int) -> void:
    agents.erase(id)

func set_distance(id: int, distance_m: float) -> bool:
    if not agents.has(id) or not is_finite(distance_m) or distance_m < 0.0:
        return false
    var data: Dictionary = agents[id]
    data["tier"] = _tier_for(distance_m)
    agents[id] = data
    return true

func advance_to(tick: int) -> PackedInt32Array:
    var due := PackedInt32Array()
    if tick <= _last_tick or tick < 0:
        return due
    _last_tick = tick
    var ids: Array = agents.keys()
    ids.sort()
    for id in ids:
        var data: Dictionary = agents[id]
        var tier: int = int(data["tier"])
        var interval: int = INTERVALS[tier]
        var last: int = int(data["last_decision_tick"])
        if last < 0 or tick - last >= interval:
            due.append(int(id))
            data["last_decision_tick"] = tick
            data["decision_count"] = int(data["decision_count"]) + 1
            _counts[tier] = int(_counts[tier]) + 1
            agents[id] = data
    return due

func snapshot(id: int) -> Dictionary:
    if not agents.has(id):
        return {}
    return (agents[id] as Dictionary).duplicate(true)

func metrics() -> Dictionary:
    return {"agents": agents.size(), "near_decisions": _counts[0], "middle_decisions": _counts[1], "far_decisions": _counts[2], "last_tick": _last_tick}

func _tier_for(distance_m: float) -> int:
    if distance_m <= near_radius_m:
        return Tier.NEAR
    if distance_m <= middle_radius_m:
        return Tier.MIDDLE
    return Tier.FAR
