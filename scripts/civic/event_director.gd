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

## GAME-023 — manual resolution and JSON-stable deterministic scheduler state.
## Keep snapshot() unchanged for existing seeded determinism tests.
func resolve_instance(instance_id: int, tick: int) -> bool:
    if tick < current_tick or not active.has(instance_id):
        return false
    current_tick = tick
    var entry: Dictionary = active[instance_id]
    budget += int(entry["cost"])
    history.append({"action": "resolved", "instance": instance_id,
        "id": entry["id"], "tick": tick})
    active.erase(instance_id)
    return true

func checkpoint_state() -> Dictionary:
    var instances: Array[Dictionary] = []
    var ids: Array = active.keys()
    ids.sort()
    for id in ids:
        var entry: Dictionary = active[id]
        instances.append({
            "instance": int(id), "id": str(entry["id"]),
            "cost": int(entry["cost"]), "end_tick": int(entry["end_tick"]),
            "tags": entry["tags"].duplicate(true)
        })
    return {"schema_version": 1, "current_tick": current_tick,
        "budget": budget, "max_concurrent": max_concurrent, "next_instance": next_instance,
        "last_started": last_started.duplicate(true), "active_instances": instances,
        "history": history.duplicate(true), "rng_state": str(rng.state)}

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
    if not (value is int or value is float):
        return false
    var n: float = float(value)
    return is_finite(n) and n == floorf(n) and n >= float(minimum) and n <= float(maximum)

func checkpoint_valid(raw: Variant) -> bool:
    if not (raw is Dictionary) or definitions.is_empty():
        return false
    var data: Dictionary = raw
    if not _whole(data.get("schema_version"), 1, 1):
        return false
    if not _whole(data.get("current_tick"), -1, 1000000000):
        return false
    if not _whole(data.get("budget"), 0, 1000000):
        return false
    if not _whole(data.get("max_concurrent"), max_concurrent, max_concurrent):
        return false
    if not _whole(data.get("next_instance"), 1, 1000000000):
        return false
    if not (data.get("rng_state") is String):
        return false
    var state_text: String = data["rng_state"]
    if not state_text.is_valid_int() or str(int(state_text)) != state_text:
        return false
    if not (data.get("last_started") is Dictionary) or not (data.get("active_instances") is Array) or not (data.get("history") is Array):
        return false
    if data["history"].size() > 10000 or data["active_instances"].size() > max_concurrent:
        return false
    for id in data["last_started"].keys():
        if not definitions.has(id) or not _whole(data["last_started"][id], 0, int(data["current_tick"])):
            return false
    var seen_instances: Dictionary = {}
    var active_cost: int = 0
    for item in data["active_instances"]:
        if not (item is Dictionary):
            return false
        if not _whole(item.get("instance"), 1, int(data["next_instance"]) - 1):
            return false
        var id: String = str(item.get("id", ""))
        var instance: int = int(item["instance"])
        if not definitions.has(id) or seen_instances.has(instance) or not data["last_started"].has(id):
            return false
        seen_instances[instance] = true
        var def: Dictionary = definitions[id]
        if not _whole(item.get("cost"), int(def["cost"]), int(def["cost"])):
            return false
        if not _whole(item.get("end_tick"), maxi(0, int(data["current_tick"]) + 1), 1000000100):
            return false
        if not (item.get("tags") is Array) or item["tags"] != def["tags"]:
            return false
        active_cost += int(item["cost"])
    if int(data["budget"]) + active_cost > 1000000:
        return false
    for event in data["history"]:
        if not (event is Dictionary):
            return false
        if not ["started", "ended", "resolved"].has(str(event.get("action", ""))):
            return false
        if not _whole(event.get("instance"), 1, int(data["next_instance"]) - 1):
            return false
        if not _whole(event.get("tick"), 0, maxi(0, int(data["current_tick"]))):
            return false
    return true

func restore_checkpoint(raw: Variant) -> bool:
    if not checkpoint_valid(raw):
        return false
    var data: Dictionary = raw
    var restored_active: Dictionary = {}
    for item in data["active_instances"]:
        var entry: Dictionary = item
        restored_active[int(entry["instance"])] = {
            "id": str(entry["id"]), "cost": int(entry["cost"]),
            "tags": entry["tags"].duplicate(true), "end_tick": int(entry["end_tick"])
        }
    var restored_history: Array[Dictionary] = []
    for entry in data["history"]:
        restored_history.append((entry as Dictionary).duplicate(true))
    active = restored_active
    history = restored_history
    last_started = data["last_started"].duplicate(true)
    current_tick = int(data["current_tick"])
    next_instance = int(data["next_instance"])
    budget = int(data["budget"])
    rng.state = int(data["rng_state"])
    return true
