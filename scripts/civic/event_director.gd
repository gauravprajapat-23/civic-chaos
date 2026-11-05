class_name CivicEventDirector
extends RefCounted
## Seeded, deterministic event scheduler with explicit resource budgets.
var rng := RandomNumberGenerator.new()
var definitions: Dictionary = {}
var active: Dictionary = {}
var last_started: Dictionary = {}
var history: Array[Dictionary] = []
var current_tick: int = -1
var budget: int = 10
var max_concurrent: int = 2
var next_instance: int = 1

func configure(seed_value: int, available_budget: int = 10, concurrency: int = 2) -> bool:
    if available_budget < 0 or concurrency < 1:
        return false
    rng.seed = seed_value
    budget = available_budget
    max_concurrent = concurrency
    return true

func register_event(definition: Dictionary) -> bool:
    var id: String = str(definition.get("id", ""))
    var cost: Variant = definition.get("cost", -1)
    var cooldown: Variant = definition.get("cooldown", -1)
    var duration: Variant = definition.get("duration", -1)
    var conditions: Variant = definition.get("conditions", {})
    var tags: Variant = definition.get("tags", [])
    if id.is_empty() or definitions.has(id) or not (cost is int) or not (cooldown is int) or not (duration is int):
        return false
    if cost < 0 or cooldown < 0 or duration <= 0 or not (conditions is Dictionary) or not (tags is Array):
        return false
    for key in conditions.keys():
        if not (conditions[key] is int):
            return false
    for tag in tags:
        if not (tag is String) or tag.is_empty():
            return false
    definitions[id] = definition.duplicate(true)
    return true

func advance_to(tick: int, metrics: Dictionary) -> Dictionary:
    if tick < current_tick:
        return {"ok": false, "reason": "stale_tick"}
    current_tick = tick
    var ending: Array = active.keys()
    ending.sort()
    for instance in ending:
        if tick >= int(active[instance]["end_tick"]):
            budget += int(active[instance]["cost"])
            history.append({"action": "ended", "instance": instance, "tick": tick})
            active.erase(instance)
    var eligible: Array[String] = []
    var ids: Array = definitions.keys()
    ids.sort()
    for id in ids:
        var definition: Dictionary = definitions[id]
        if int(definition["cost"]) > budget or active.size() >= max_concurrent:
            continue
        if last_started.has(id) and tick < int(last_started[id]) + int(definition["cooldown"]):
            continue
        var same_active := false
        var conflict := false
        for instance in active.keys():
            var other: Dictionary = active[instance]
            if other["id"] == id:
                same_active = true
            for tag in definition["tags"]:
                if (other["tags"] as Array).has(tag):
                    conflict = true
        if same_active or conflict:
            continue
        var conditions_met := true
        for key in definition["conditions"].keys():
            if not metrics.has(key) or not (metrics[key] is int) or int(metrics[key]) < int(definition["conditions"][key]):
                conditions_met = false
                break
        if conditions_met:
            eligible.append(id)
    if eligible.is_empty():
        return {"ok": true, "started": ""}
    var chosen: String = eligible[rng.randi_range(0, eligible.size() - 1)]
    var entry: Dictionary = definitions[chosen]
    var instance_id := next_instance
    next_instance += 1
    budget -= int(entry["cost"])
    active[instance_id] = {"id": chosen, "cost": entry["cost"], "tags": entry["tags"].duplicate(), "end_tick": tick + int(entry["duration"])}
    last_started[chosen] = tick
    history.append({"action": "started", "instance": instance_id, "id": chosen, "tick": tick})
    return {"ok": true, "started": chosen, "instance": instance_id}

func snapshot() -> Dictionary:
    return {"budget": budget, "current_tick": current_tick, "active": active.duplicate(true), "last_started": last_started.duplicate(true), "history": history.duplicate(true), "next_instance": next_instance, "rng_state": rng.state}
