class_name CivicDebugTelemetry
extends RefCounted
## JSON-safe, bounded developer telemetry with monotonic simulation ticks.
const SCHEMA_VERSION := 1
const MAX_SAMPLES := 512
var samples: Array[Dictionary] = []
var last_tick: int = -1

func record(tick: int, traffic: Dictionary, routes: Dictionary, reservations: Dictionary, decisions: Dictionary, deadlocks: Dictionary, timing: Dictionary) -> bool:
    if tick < 0 or tick <= last_tick:
        return false
    var payload := {"tick": tick, "traffic": traffic, "routes": routes, "reservations": reservations, "decisions": decisions, "deadlocks": deadlocks, "timing": timing}
    if not _json_safe(payload):
        return false
    samples.append(payload.duplicate(true))
    if samples.size() > MAX_SAMPLES:
        samples.remove_at(0)
    last_tick = tick
    return true

func latest() -> Dictionary:
    return {} if samples.is_empty() else samples.back().duplicate(true)

func export_document() -> Dictionary:
    return {"schema_version": SCHEMA_VERSION, "sample_count": samples.size(), "samples": samples.duplicate(true)}

func export_json(path: String) -> bool:
    if not path.begins_with("user://") or not path.ends_with(".json"):
        return false
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(export_document(), "  "))
    file.close()
    return true

func _json_safe(value: Variant) -> bool:
    if value == null or value is bool or value is String or value is int:
        return true
    if value is float:
        return is_finite(value)
    if value is Array:
        for item in value:
            if not _json_safe(item):
                return false
        return true
    if value is Dictionary:
        for key in value.keys():
            if not (key is String) or not _json_safe(value[key]):
                return false
        return true
    return false
