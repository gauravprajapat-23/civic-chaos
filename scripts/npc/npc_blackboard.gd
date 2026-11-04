class_name CivicNpcBlackboard
extends RefCounted
## Immutable-by-copy snapshots of an NPC's most recent observations.

var npc_id: int = -1
var tick_index: int = -1
var observations: Dictionary = {}

func update_snapshot(id: int, tick: int, new_observations: Dictionary) -> bool:
    if id < 0 or tick < 0 or (npc_id >= 0 and id != npc_id) or tick < tick_index:
        return false
    if not _is_json_safe(new_observations):
        return false
    npc_id = id
    tick_index = tick
    observations = new_observations.duplicate(true)
    return true

func snapshot() -> Dictionary:
    return {"npc_id": npc_id, "tick_index": tick_index, "observations": observations.duplicate(true)}

func to_json() -> String:
    return JSON.stringify(snapshot())

static func from_json(json_text: String) -> CivicNpcBlackboard:
    var parsed: Variant = JSON.parse_string(json_text)
    if not parsed is Dictionary:
        return null
    var data: Dictionary = parsed
    if not data.has("npc_id") or not data.has("tick_index") or not (data.get("observations") is Dictionary):
        return null
    var board := CivicNpcBlackboard.new()
    if not board.update_snapshot(int(data["npc_id"]), int(data["tick_index"]), data["observations"]):
        return null
    return board

static func _is_json_safe(value: Variant) -> bool:
    if value is Dictionary:
        for key in value.keys():
            if not (key is String) or not _is_json_safe(value[key]):
                return false
        return true
    if value is Array:
        for item in value:
            if not _is_json_safe(item):
                return false
        return true
    if value is float:
        return is_finite(value)
    return value == null or value is String or value is bool or value is int
