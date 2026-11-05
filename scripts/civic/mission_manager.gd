class_name CivicMissionManager
extends RefCounted
## Data-driven mission progress with idempotent rewards and JSON-safe snapshots.

const AVAILABLE := "available"
const ACTIVE := "active"
const COMPLETED := "completed"
const FAILED := "failed"

var missions: Dictionary = {}
var rewarded: Dictionary = {}

func register_mission(definition: Dictionary) -> bool:
    var id: String = str(definition.get("id", ""))
    var objectives: Variant = definition.get("objectives", [])
    if id.is_empty() or missions.has(id) or not (objectives is Array) or objectives.is_empty():
        return false
    var seen: Dictionary = {}
    for objective in objectives:
        if not (objective is Dictionary):
            return false
        var key: String = str(objective.get("event", ""))
        var target: Variant = objective.get("target", 0)
        if key.is_empty() or seen.has(key) or not (target is int) or int(target) <= 0:
            return false
        seen[key] = true
    var progress: Dictionary = {}
    for objective in objectives:
        progress[str(objective["event"])] = 0
    missions[id] = {"id": id, "state": AVAILABLE, "objectives": objectives.duplicate(true), "progress": progress, "reward": maxi(0, int(definition.get("reward", 0)))}
    return true

func start(id: String) -> bool:
    if not missions.has(id) or missions[id]["state"] != AVAILABLE:
        return false
    missions[id]["state"] = ACTIVE
    return true

func record_event(id: String, event_name: String, amount: int = 1) -> bool:
    if not missions.has(id) or missions[id]["state"] != ACTIVE or amount <= 0:
        return false
    var mission: Dictionary = missions[id]
    var progress: Dictionary = mission["progress"]
    if not progress.has(event_name):
        return false
    for objective in mission["objectives"]:
        if objective["event"] == event_name:
            progress[event_name] = mini(int(objective["target"]), int(progress[event_name]) + amount)
            break
    var all_done := true
    for objective in mission["objectives"]:
        if int(progress[objective["event"]]) < int(objective["target"]):
            all_done = false
            break
    if all_done:
        mission["state"] = COMPLETED
    return true

func fail(id: String) -> bool:
    if not missions.has(id) or missions[id]["state"] != ACTIVE:
        return false
    missions[id]["state"] = FAILED
    return true

func claim_reward(id: String) -> int:
    if not missions.has(id) or missions[id]["state"] != COMPLETED or rewarded.has(id):
        return 0
    rewarded[id] = true
    return int(missions[id]["reward"])

func snapshot() -> Dictionary:
    return {"missions": missions.duplicate(true), "rewarded": rewarded.duplicate(true)}

func restore(data: Dictionary) -> bool:
    if not (data.get("missions") is Dictionary) or not (data.get("rewarded") is Dictionary):
        return false
    var restored: Dictionary = data["missions"]
    var claimed: Dictionary = data["rewarded"]
    for id in restored.keys():
        var mission: Variant = restored[id]
        if not (mission is Dictionary) or not [AVAILABLE, ACTIVE, COMPLETED, FAILED].has(mission.get("state", "")):
            return false
        if not (mission.get("objectives") is Array) or not (mission.get("progress") is Dictionary):
            return false
        for objective in mission["objectives"]:
            if not (objective is Dictionary) or not mission["progress"].has(objective.get("event", "")):
                return false
    for id in claimed.keys():
        if not restored.has(id) or restored[id]["state"] != COMPLETED or claimed[id] != true:
            return false
    missions = restored.duplicate(true)
    rewarded = claimed.duplicate(true)
    return true
