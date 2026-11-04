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
