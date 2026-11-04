class_name CivicRoadGraph
extends RefCounted
## Validated directed lane graph. Routing is implemented in CC-007.

const CONNECTION_TOLERANCE_M: float = 2.0

var _lanes: Dictionary = {}

func add_lane(lane: CivicLaneData) -> bool:
    if lane == null or lane.lane_id < 0 or _lanes.has(lane.lane_id):
        return false
    _lanes[lane.lane_id] = lane
    return true

func get_lane(lane_id: int) -> CivicLaneData:
    return _lanes.get(lane_id) as CivicLaneData

func has_lane(lane_id: int) -> bool:
    return _lanes.has(lane_id)

func lane_count() -> int:
    return _lanes.size()

func clear() -> void:
    _lanes.clear()

func sorted_lane_ids() -> Array[int]:
    var ids: Array[int] = []
    for key in _lanes.keys():
        ids.append(int(key))
    ids.sort()
    return ids

func outgoing_legal_lanes(lane_id: int, vehicle_mask: int) -> Array[int]:
    var result: Array[int] = []
    var source := get_lane(lane_id)
    if source == null or source.is_wrong_way_connector:
        return result
    for next_id in source.next_lane_ids:
        var target := get_lane(next_id)
        if target != null and not target.is_wrong_way_connector and target.is_vehicle_allowed(vehicle_mask):
            result.append(next_id)
    result.sort()
    return result

func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    for id in sorted_lane_ids():
        var lane := get_lane(id)
        for error in lane.geometry_errors():
            errors.append("lane %d: %s" % [id, error])
        if lane.lane_id != id:
            errors.append("lane %d: stored ID changed after insertion" % id)
        var seen: Dictionary = {}
        for next_id in lane.next_lane_ids:
            if seen.has(next_id):
                errors.append("lane %d: duplicate connection to %d" % [id, next_id])
                continue
            seen[next_id] = true
            if next_id == id:
                errors.append("lane %d: self connection" % id)
            var target := get_lane(next_id)
            if target == null:
                errors.append("lane %d: missing connection target %d" % [id, next_id])
                continue
            if lane.centerline.size() < 2 or target.centerline.size() < 2:
                continue
            var gap := lane.centerline[lane.centerline.size() - 1].distance_to(target.centerline[0])
            if gap > CONNECTION_TOLERANCE_M:
                errors.append("lane %d: connection to %d has %.2fm gap" % [id, next_id, gap])
            if not lane.is_wrong_way_connector and target.is_wrong_way_connector:
                errors.append("lane %d: legal lane connects to wrong-way connector %d" % [id, next_id])
    return errors
