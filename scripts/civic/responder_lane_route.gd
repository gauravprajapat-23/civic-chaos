class_name CivicResponderLaneRoute
extends RefCounted
## GAME-002: directed vehicle lane route, not undirected pedestrian guidance.
## Outputs dense waypoints and matching authoritative lane progress. Traffic
## can verify each proposed movement without selecting a "nearest green" lane.
const MAX_ENDPOINT_OFFSET_M: float = 2.45
const SAMPLE_SPACING_M: float = 0.75

static func _projection(lane: CivicLaneData, point: Vector3) -> Dictionary:
    var best: float = INF
    var distance: float = 0.0
    var along: float = 0.0
    var closest: Vector3 = Vector3.ZERO
    for i in range(1, lane.centerline.size()):
        var a: Vector3 = lane.centerline[i - 1]
        var b: Vector3 = lane.centerline[i]
        var offset := Vector2(point.x - a.x, point.z - a.z)
        var delta := Vector2(b.x - a.x, b.z - a.z)
        var t: float = clampf(offset.dot(delta) / maxf(delta.length_squared(), 0.000001), 0.0, 1.0)
        var position: Vector3 = a.lerp(b, t)
        var gap: float = Vector2(point.x - position.x, point.z - position.z).length()
        if gap < best:
            best = gap
            distance = along + a.distance_to(b) * t
            closest = position
        along += a.distance_to(b)
    return {"offset": best, "distance": distance, "point": closest}

static func _point_at(lane: CivicLaneData, distance: float) -> Vector3:
    var remaining: float = clampf(distance, 0.0, lane.length_m())
    for i in range(1, lane.centerline.size()):
        var a: Vector3 = lane.centerline[i - 1]
        var b: Vector3 = lane.centerline[i]
        var length: float = a.distance_to(b)
        if remaining <= length:
            return a.lerp(b, remaining / maxf(length, 0.000001))
        remaining -= length
    return lane.centerline[-1]

static func plan(graph: CivicRoadGraph, start: Vector3, goal: Vector3) -> Dictionary:
    var invalid: Dictionary = {"ok": false, "reason": "no_directed_route"}
    if graph == null or not start.is_finite() or not goal.is_finite():
        return invalid
    var candidates_start: Array[Dictionary] = []
    var candidates_goal: Dictionary = {}
    for lane_id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(lane_id)
        if lane == null or lane.is_wrong_way_connector or not lane.is_vehicle_allowed(1):
            continue
        var a: Dictionary = _projection(lane, start)
        var b: Dictionary = _projection(lane, goal)
        if float(a["offset"]) <= MAX_ENDPOINT_OFFSET_M:
            candidates_start.append({"id": lane_id, "distance": float(a["distance"]), "offset": float(a["offset"])})
        if float(b["offset"]) <= MAX_ENDPOINT_OFFSET_M:
            candidates_goal[lane_id] = b
    if candidates_start.is_empty() or candidates_goal.is_empty():
        return invalid
    # Dijkstra over directed *lane connections*. Start/end may lie inside
    # their lanes; a same-lane route is valid only in forward direction.
    var best_cost: float = INF
    var best_route := PackedInt32Array()
    var first_distance: float = 0.0
    var last_distance: float = 0.0
    for origin in candidates_start:
        var source: int = int(origin["id"])
        var distances: Dictionary = {source: 0.0}
        var previous: Dictionary = {}
        var visited: Dictionary = {}
        while true:
            var current: int = -1
            var cheapest: float = INF
            for key in distances.keys():
                if not visited.has(key) and float(distances[key]) < cheapest:
                    cheapest = float(distances[key])
                    current = int(key)
            if current < 0:
                break
            visited[current] = true
            var current_lane: CivicLaneData = graph.get_lane(current)
            for next_id in graph.outgoing_legal_lanes(current, 1):
                if visited.has(next_id):
                    continue
                var proposal: float = cheapest + current_lane.length_m()
                if proposal < float(distances.get(next_id, INF)):
                    distances[next_id] = proposal
                    previous[next_id] = current
        for destination in candidates_goal.keys():
            if not distances.has(destination):
                continue
            var end_distance: float = float(candidates_goal[destination]["distance"])
            if source == int(destination) and end_distance < float(origin["distance"]):
                continue
            var cost: float = float(distances[destination]) + end_distance - float(origin["distance"]) + float(origin["offset"]) + float(candidates_goal[destination]["offset"])
            if cost >= best_cost:
                continue
            var chain: Array[int] = [int(destination)]
            var cursor: int = int(destination)
            while cursor != source:
                if not previous.has(cursor):
                    chain.clear()
                    break
                cursor = int(previous[cursor])
                chain.push_front(cursor)
            if chain.is_empty():
                continue
            best_cost = cost
            best_route = PackedInt32Array(chain)
            first_distance = float(origin["distance"])
            last_distance = end_distance
    if best_route.is_empty():
        return invalid
    var points := PackedVector3Array()
    var indices := PackedInt32Array()
    var progress := PackedFloat32Array()
    # The van begins at the approved depot. The first real lane sample is
    # its projected entry, within the Traffic adapter's lateral tolerance.
    points.append(start)
    indices.append(0)
    progress.append(first_distance)
    for lane_index in range(best_route.size()):
        var lane: CivicLaneData = graph.get_lane(best_route[lane_index])
        var start_m: float = first_distance if lane_index == 0 else 0.0
        var end_m: float = last_distance if lane_index == best_route.size() - 1 else lane.length_m()
        if end_m < start_m:
            return invalid
        var start_point: Vector3 = _point_at(lane, start_m)
        if points[-1].distance_to(start_point) > 0.01:
            points.append(start_point)
            indices.append(lane_index)
            progress.append(start_m)
        else:
            indices[indices.size() - 1] = lane_index
            progress[progress.size() - 1] = start_m
        var segment_count: int = maxi(1, int(ceil((end_m - start_m) / SAMPLE_SPACING_M)))
        for j in range(1, segment_count + 1):
            var at_m: float = lerpf(start_m, end_m, float(j) / float(segment_count))
            points.append(_point_at(lane, at_m))
            indices.append(lane_index)
            progress.append(at_m)
    # If the depot or stop requires an excessively long off-lane connector,
    # reject instead of inventing drivable geometry.
    if points.size() < 2:
        return invalid
    return {"ok": true, "points": points, "lane_ids": best_route,
        "lane_indices": indices, "lane_progress_m": progress,
        "distance_m": best_cost}
