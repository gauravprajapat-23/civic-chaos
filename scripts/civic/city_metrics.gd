class_name CivicCityMetrics
extends RefCounted
## Fixed-point civic scores, bounded 0..1000 to avoid floating-point drift.
const MIN_SCORE := 0
const MAX_SCORE := 1000
const DEFAULT_SCORE := 500
const DIMENSIONS := ["safety", "efficiency", "trust", "cooperation"]

var scores: Dictionary = {"safety": 500, "efficiency": 500, "trust": 500, "cooperation": 500}
var processed_events: Dictionary = {}
var history: Array[Dictionary] = []
var last_tick: int = -1

func apply_outcome(event_id: String, tick: int, changes: Dictionary, reason: String) -> bool:
    if event_id.is_empty() or reason.is_empty() or tick < last_tick or processed_events.has(event_id) or changes.is_empty():
        return false
    for key in changes.keys():
        if not DIMENSIONS.has(key) or not (changes[key] is int) or absi(int(changes[key])) > 100:
            return false
    var applied: Dictionary = {}
    for key in DIMENSIONS:
        var previous: int = int(scores[key])
        var updated: int = clampi(previous + int(changes.get(key, 0)), MIN_SCORE, MAX_SCORE)
        scores[key] = updated
        applied[key] = updated - previous
    processed_events[event_id] = true
    last_tick = tick
    history.append({"id": event_id, "tick": tick, "reason": reason, "applied": applied})
    return true

func reputation() -> int:
    var sum: int = 0
    for key in DIMENSIONS:
        sum += int(scores[key])
    return sum / DIMENSIONS.size()

func snapshot() -> Dictionary:
    return {"scores": scores.duplicate(true), "processed_events": processed_events.duplicate(true), "history": history.duplicate(true), "last_tick": last_tick}

func restore(data: Dictionary) -> bool:
    if not (data.get("scores") is Dictionary) or not (data.get("processed_events") is Dictionary) or not (data.get("history") is Array) or not (data.get("last_tick") is int):
        return false
    var candidate: Dictionary = data["scores"]
    if candidate.size() != DIMENSIONS.size():
        return false
    for key in DIMENSIONS:
        if not candidate.has(key) or not (candidate[key] is int) or int(candidate[key]) < MIN_SCORE or int(candidate[key]) > MAX_SCORE:
            return false
    for id in data["processed_events"].keys():
        if str(id).is_empty() or data["processed_events"][id] != true:
            return false
    # JSON.parse_string produces a plain Array even when the original history
    # was Array[Dictionary]. Build a typed array explicitly; assigning the
    # untyped deep-copy directly produces a Godot runtime type error.
    var restored_history: Array[Dictionary] = []
    for raw_entry in data["history"]:
        if not (raw_entry is Dictionary):
            return false
        var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
        if not (entry.get("id") is String) or str(entry["id"]).is_empty():
            return false
        if not (entry.get("reason") is String) or str(entry["reason"]).is_empty():
            return false
        if not (entry.get("applied") is Dictionary):
            return false
        restored_history.append(entry)
    # Do not mutate any live scores or audit records before all validation
    # succeeds; malformed saves must leave the current manager unchanged.
    scores = candidate.duplicate(true)
    processed_events = data["processed_events"].duplicate(true)
    history = restored_history
    last_tick = int(data["last_tick"])
    return true
