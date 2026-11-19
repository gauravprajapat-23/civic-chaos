class_name CivicCallLaneRoute
extends RefCounted
## GAME-002: deterministic directed vehicle route; never use pedestrian map routes.
## Every movement leg is mapped to a verified lane from the graph.
const ENDPOINT_TOLERANCE_M: float = 2.5

static func _project(lane: CivicLaneData, point: Vector3) -> Dictionary:
    var best: Dictionary = {"distance_m": 0.0, "lateral_m": INF}
    var travelled: float = 0.0
    for i in range(1, lane.centerline.size()):
        var a: Vector3 = lane.centerline[i - 1]
        var b: Vector3 = lane.centerline[i]
        var ab := Vector2(b.x - a.x, b.z - a.z)
        var ap := Vector2(point.x - a.x, point.z - a.z)
        var fraction: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
        var lateral: float = (ap - ab * fraction).length()
        if lateral < float(best["lateral_m"]):
            best = {"distance_m": travelled + (b - a).length() * fraction, "lateral_m": lateral}
        travelled += (b - a).length()
    return best

static func _point_at(lane: CivicLaneData, distance_m: float) -> Vector3:
    var traversed: float = 0.0
    for i in range(1, lane.centerline.size()):
        var a: Vector3 = lane.centerline[i - 1]
        var b: Vector3 = lane.centerline[i]
        var length: float = a.distance_to(b)
        if traversed + length >= distance_m:
            return a.lerp(b, clampf((distance_m - traversed) / maxf(length, 0.000001), 0.0, 1.0))
        traversed += length
    return lane.centerline[lane.centerline.size() - 1]

static func _fail() -> Dictionary:
    return {"ok": false, "points": PackedVector3Array(), "lane_ids": PackedInt32Array(),
        "leg_lanes": PackedInt32Array()}

static func plan(graph: CivicRoadGraph, start: Vector3, finish: Vector3) -> Dictionary:
    if graph == null or not start.is_finite() or not finish.is_finite():
        return _fail()
    var starts: Array[Dictionary] = []
    var ends: Array[Dictionary] = []
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if lane == null or lane.is_wrong_way_connector or not lane.is_vehicle_allowed(1) or lane.centerline.size() < 2:
            continue
        var a: Dictionary = _project(lane, start)
        var b: Dictionary = _project(lane, finish)
        if float(a["lateral_m"]) <= ENDPOINT_TOLERANCE_M:
            starts.append({"id": id, "offset": float(a["distance_m"])})
        if float(b["lateral_m"]) <= ENDPOINT_TOLERANCE_M:
            ends.append({"id": id, "offset": float(b["distance_m"])})
    var best_route: PackedInt32Array = PackedInt32Array()
    var best_cost: float = INF
    var first_offset: float = 0.0
    var last_offset: float = 0.0
    for source in starts:
        var frontier: Array[int] = [int(source["id"])]
        var cost: Dictionary = {int(source["id"]): 0.0}
        var previous: Dictionary = {}
        while not frontier.is_empty():
            frontier.sort_custom(func(a: int, b: int) -> bool:
                return float(cost[a]) < float(cost[b]) or (is_equal_approx(float(cost[a]), float(cost[b])) and a < b))
            var current: int = frontier.pop_front()
            for next_id in graph.outgoing_legal_lanes(current, 1):
                var candidate: float = float(cost[current]) + graph.get_lane(current).length_m()
                if candidate < float(cost.get(next_id, INF)) - 0.001:
                    cost[next_id] = candidate
                    previous[next_id] = current
                    if not frontier.has(next_id):
                        frontier.append(next_id)
        for goal in ends:
            var goal_id: int = int(goal["id"])
            if not cost.has(goal_id):
                continue
            if goal_id == int(source["id"]) and float(goal["offset"]) <= float(source["offset"]):
                continue
            var total: float = float(cost[goal_id]) + float(goal["offset"]) - float(source["offset"])
            if total >= best_cost - 0.001:
                continue
            var reverse: Array[int] = [goal_id]
            var cursor: int = goal_id
            while cursor != int(source["id"]):
                if not previous.has(cursor):
                    break
                cursor = int(previous[cursor])
                reverse.append(cursor)
            if cursor != int(source["id"]):
                continue
            reverse.reverse()
            best_route = PackedInt32Array(reverse)
            best_cost = total
            first_offset = float(source["offset"])
            last_offset = float(goal["offset"])
    if best_route.is_empty():
        return _fail()
    var points := PackedVector3Array()
    var legs := PackedInt32Array()
    var first_lane: CivicLaneData = graph.get_lane(best_route[0])
    points.append(_point_at(first_lane, first_offset))
    for lane_index in range(best_route.size()):
        var lane: CivicLaneData = graph.get_lane(best_route[lane_index])
        var begin: float = first_offset if lane_index == 0 else 0.0
        var end: float = last_offset if lane_index == best_route.size() - 1 else lane.length_m()
        var walked: float = 0.0
        for k in range(1, lane.centerline.size()):
            walked += lane.centerline[k - 1].distance_to(lane.centerline[k])
            if walked > begin + 0.001 and walked < end - 0.001:
                points.append(lane.centerline[k])
                legs.append(lane_index)
        var endpoint: Vector3 = _point_at(lane, end)
        if points[points.size() - 1].distance_to(endpoint) > 0.001:
            points.append(endpoint)
            legs.append(lane_index)
    if points.size() < 2 or legs.size() != points.size() - 1:
        return _fail()
    return {"ok": true, "points": points, "lane_ids": best_route,
        "leg_lanes": legs, "distance_m": best_cost}
