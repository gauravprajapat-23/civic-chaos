class_name CivicIntersectionReservations
extends RefCounted
## Deterministic time-window reservations for named intersection conflict zones.
## Windows are half-open [start_tick, end_tick). Occupancy blocks every reservation.

var _reservations: Array[Dictionary] = []
var _occupied: Dictionary = {}
var current_tick: int = 0

func request(vehicle_id: int, zones: PackedStringArray, start_tick: int, end_tick: int) -> Dictionary:
    if vehicle_id < 0 or zones.is_empty() or start_tick < current_tick or end_tick <= start_tick:
        return {"granted": false, "reason": "invalid_request"}
    var unique_zones: Dictionary = {}
    for zone in zones:
        if zone.is_empty() or unique_zones.has(zone):
            return {"granted": false, "reason": "invalid_zones"}
        unique_zones[zone] = true
        if _occupied.has(zone) and int(_occupied[zone]) != vehicle_id:
            return {"granted": false, "reason": "occupied"}
    for reservation in _reservations:
        if int(reservation["vehicle_id"]) == vehicle_id:
            continue
        if start_tick < int(reservation["end_tick"]) and end_tick > int(reservation["start_tick"]):
            for zone in zones:
                if (reservation["zones"] as PackedStringArray).has(zone):
                    return {"granted": false, "reason": "conflict"}
    # Repeated identical requests from a vehicle are idempotent.
    for reservation in _reservations:
        if int(reservation["vehicle_id"]) == vehicle_id and int(reservation["start_tick"]) == start_tick and int(reservation["end_tick"]) == end_tick and (reservation["zones"] as PackedStringArray) == zones:
            return {"granted": true, "reason": "existing"}
    _reservations.append({"vehicle_id": vehicle_id, "zones": zones.duplicate(), "start_tick": start_tick, "end_tick": end_tick})
    return {"granted": true, "reason": "granted"}

func occupy(vehicle_id: int, zone: String) -> bool:
    if vehicle_id < 0 or zone.is_empty():
        return false
    if _occupied.has(zone):
        return int(_occupied[zone]) == vehicle_id
    var authorized := false
    for reservation in _reservations:
        if int(reservation["vehicle_id"]) == vehicle_id and current_tick >= int(reservation["start_tick"]) and current_tick < int(reservation["end_tick"]) and (reservation["zones"] as PackedStringArray).has(zone):
            authorized = true
            break
    if not authorized:
        return false
    _occupied[zone] = vehicle_id
    return true

func release(vehicle_id: int, zone: String) -> bool:
    if not _occupied.has(zone) or int(_occupied[zone]) != vehicle_id:
        return false
    _occupied.erase(zone)
    return true

func cancel(vehicle_id: int) -> void:
    # An occupied zone remains protected until its owner explicitly releases it.
    _reservations = _reservations.filter(func(entry: Dictionary) -> bool: return int(entry["vehicle_id"]) != vehicle_id)

func advance_to(tick: int) -> bool:
    if tick < current_tick:
        return false
    current_tick = tick
    _reservations = _reservations.filter(func(entry: Dictionary) -> bool: return int(entry["end_tick"]) > current_tick)
    return true

func active_reservation_count() -> int:
    return _reservations.size()

func occupant(zone: String) -> int:
    return int(_occupied.get(zone, -1))

func reset() -> void:
    current_tick = 0
    _reservations.clear()
    _occupied.clear()

## GAME-019: preserve reservations together with their exact occupied zones.
## All IDs are logical actor IDs from this simulation, never node instance IDs.
func snapshot() -> Dictionary:
    var saved: Array[Dictionary] = []
    for entry in _reservations:
        var zones: Array[String] = []
        for zone in entry["zones"]:
            zones.append(zone)
        saved.append({
            "vehicle_id": int(entry["vehicle_id"]),
            "zones": zones,
            "start_tick": int(entry["start_tick"]),
            "end_tick": int(entry["end_tick"])
        })
    return {"schema_version": 1, "current_tick": current_tick,
        "reservations": saved, "occupied": _occupied.duplicate(true)}

static func _valid_whole(raw: Variant, minimum: int, maximum: int) -> bool:
    if not (raw is int or raw is float):
        return false
    var value: float = float(raw)
    return is_finite(value) and value == floorf(value) and value >= minimum and value <= maximum

func can_restore(raw: Variant) -> bool:
    if not (raw is Dictionary):
        return false
    var data: Dictionary = raw
    if not _valid_whole(data.get("schema_version"), 1, 1) or not _valid_whole(data.get("current_tick"), 0, 1000000000):
        return false
    if not (data.get("reservations") is Array) or not (data.get("occupied") is Dictionary):
        return false
    if data["reservations"].size() > 256 or data["occupied"].size() > 64:
        return false
    var pending: Array[Dictionary] = []
    for raw_entry in data["reservations"]:
        if not (raw_entry is Dictionary):
            return false
        var entry: Dictionary = raw_entry
        if not _valid_whole(entry.get("vehicle_id"), 0, 1000000000) or not _valid_whole(entry.get("start_tick"), 0, 1000000000) or not _valid_whole(entry.get("end_tick"), 1, 1000000000):
            return false
        if int(entry["start_tick"]) >= int(entry["end_tick"]) or int(entry["end_tick"]) <= int(data["current_tick"]):
            return false
        if not (entry.get("zones") is Array) or entry["zones"].is_empty() or entry["zones"].size() > 16:
            return false
        var unique: Dictionary = {}
        for zone in entry["zones"]:
            if not (zone is String) or zone.is_empty() or zone.length() > 64 or unique.has(zone):
                return false
            unique[zone] = true
        for other in pending:
            if int(other["vehicle_id"]) == int(entry["vehicle_id"]):
                continue
            if int(entry["start_tick"]) < int(other["end_tick"]) and int(entry["end_tick"]) > int(other["start_tick"]):
                for zone in entry["zones"]:
                    if other["zones"].has(zone):
                        return false
        pending.append(entry)
    var occupied: Dictionary = data["occupied"]
    for zone in occupied.keys():
        if not (zone is String) or zone.is_empty() or zone.length() > 64 or not _valid_whole(occupied[zone], 0, 1000000000):
            return false
    return true

func restore(raw: Variant) -> bool:
    if not can_restore(raw):
        return false
    var data: Dictionary = raw
    var restored: Array[Dictionary] = []
    for entry in data["reservations"]:
        var zones := PackedStringArray()
        for zone in entry["zones"]:
            zones.append(zone)
        restored.append({
            "vehicle_id": int(entry["vehicle_id"]),
            "zones": zones,
            "start_tick": int(entry["start_tick"]),
            "end_tick": int(entry["end_tick"])
        })
    current_tick = int(data["current_tick"])
    _reservations = restored
    _occupied = data["occupied"].duplicate(true)
    return true
