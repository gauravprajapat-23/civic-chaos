class_name CivicIncidentManager
extends RefCounted
## Deterministic civic incident state machine and causal audit history.

const ACTIVE := "active"
const ESCALATED := "escalated"
const INTERVENTION := "intervention"
const RESOLVED := "resolved"
var incidents: Dictionary = {}
var event_log: Array[Dictionary] = []
var next_id: int = 1
var current_tick: int = 0

func create_incident(kind: String, source_id: int, tick: int, location_key: String) -> Dictionary:
    if kind.is_empty() or source_id < 0 or location_key.is_empty() or tick < current_tick:
        return {"ok": false, "reason": "invalid_incident"}
    for id in incidents.keys():
        var existing: Dictionary = incidents[id]
        if existing["kind"] == kind and existing["source_id"] == source_id and existing["location_key"] == location_key and existing["state"] != RESOLVED:
            return {"ok": true, "id": int(id), "duplicate": true}
    current_tick = tick
    var id := next_id
    next_id += 1
    incidents[id] = {"id": id, "kind": kind, "source_id": source_id, "location_key": location_key, "state": ACTIVE, "created_tick": tick, "updated_tick": tick}
    _record(id, "created", tick, "observation")
    return {"ok": true, "id": id, "duplicate": false}

func transition(id: int, next_state: String, tick: int, cause: String) -> bool:
    if not incidents.has(id) or tick < current_tick or cause.is_empty():
        return false
    var incident: Dictionary = incidents[id]
    var previous: String = incident["state"]
    var allowed: Dictionary = {
        ACTIVE: [ESCALATED, INTERVENTION],
        ESCALATED: [INTERVENTION],
        INTERVENTION: [RESOLVED, ESCALATED],
        RESOLVED: []
    }
    if not (allowed[previous] as Array).has(next_state):
        return false
    current_tick = tick
    incident["state"] = next_state
    incident["updated_tick"] = tick
    incidents[id] = incident
    _record(id, next_state, tick, cause)
    return true

func advance_to(tick: int) -> bool:
    if tick < current_tick:
        return false
    current_tick = tick
    return true

func snapshot() -> Dictionary:
    var entries: Array[Dictionary] = []
    var ids: Array = incidents.keys()
    ids.sort()
    for id in ids:
        entries.append((incidents[id] as Dictionary).duplicate(true))
    return {"next_id": next_id, "current_tick": current_tick, "incidents": entries, "events": event_log.duplicate(true)}

func to_json() -> String:
    return JSON.stringify(snapshot())

static func from_json(data: String) -> CivicIncidentManager:
    # Invalid network/save payloads must be rejected without producing
    # Godot engine errors. JSON.parse_string emits ERROR on malformed text.
    var parser := JSON.new()
    if parser.parse(data) != OK:
        return null
    var parsed: Variant = parser.data
    if not parsed is Dictionary:
        return null
    var value: Dictionary = parsed
    if not value.has("incidents") or not (value["incidents"] is Array) or not value.has("events") or not (value["events"] is Array):
        return null
    var manager := CivicIncidentManager.new()
    manager.next_id = int(value.get("next_id", 0))
    manager.current_tick = int(value.get("current_tick", -1))
    if manager.next_id < 1 or manager.current_tick < 0:
        return null
    for entry in value["incidents"]:
        if not (entry is Dictionary) or not entry.has("id") or not entry.has("state"):
            return null
        var id := int(entry["id"])
        if id < 1 or manager.incidents.has(id) or not [ACTIVE, ESCALATED, INTERVENTION, RESOLVED].has(entry["state"]):
            return null
        manager.incidents[id] = (entry as Dictionary).duplicate(true)
    for event in value["events"]:
        if not (event is Dictionary):
            return null
        manager.event_log.append((event as Dictionary).duplicate(true))
    return manager

func _record(id: int, action: String, tick: int, cause: String) -> void:
    event_log.append({"incident_id": id, "event": action, "tick": tick, "cause": cause})
