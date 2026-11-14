class_name CivicMapRoutes
extends RefCounted
## AUD3-MAP-02: deterministic walking guidance over real road-graph nodes.
## This is NOT vehicle routing, live congestion avoidance or GPS.
const NEAR_EPS: float = 0.1

static func _key(point: Vector3) -> String:
    return "%.2f:%.2f" % [point.x, point.z]

static func plan(graph: CivicRoadGraph, start: Vector3, goal: Vector3) -> Dictionary:
    if graph == null or not start.is_finite() or not goal.is_finite():
        return {"ok": false, "reason": "missing_route_data", "points": PackedVector3Array()}
    var nodes: Dictionary = {}
    var edges: Dictionary = {}
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if lane == null or lane.is_wrong_way_connector or lane.centerline.size() < 2:
            continue
        var begin: Vector3 = lane.centerline[0]
        var finish: Vector3 = lane.centerline[lane.centerline.size() - 1]
        var a: String = _key(begin)
        var b: String = _key(finish)
        nodes[a] = begin
        nodes[b] = finish
        if not edges.has(a):
            edges[a] = {}
        if not edges.has(b):
            edges[b] = {}
        # Pedestrian guidance is undirected along actual paved segments;
        # traffic's vehicle restrictions are deliberately not modified.
        var distance: float = lane.length_m()
        edges[a][b] = minf(float(edges[a].get(b, INF)), distance)
        edges[b][a] = minf(float(edges[b].get(a, INF)), distance)
    if nodes.is_empty():
        return {"ok": false, "reason": "empty_graph", "points": PackedVector3Array()}
    var source: String = ""
    var destination: String = ""
    var start_distance: float = INF
    var end_distance: float = INF
    for key in nodes.keys():
        var point: Vector3 = nodes[key]
        var first: float = _horizontal_distance(start, point)
        var last: float = _horizontal_distance(goal, point)
        if first < start_distance or (is_equal_approx(first, start_distance) and (source.is_empty() or str(key) < source)):
            source = key
            start_distance = first
        if last < end_distance or (is_equal_approx(last, end_distance) and (destination.is_empty() or str(key) < destination)):
            destination = key
            end_distance = last
    var costs: Dictionary = {source: 0.0}
    var previous: Dictionary = {}
    var visited: Dictionary = {}
    while true:
        var current: String = ""
        var cheapest: float = INF
        for key in costs.keys():
            var candidate: float = float(costs[key])
            if visited.has(key):
                continue
            if candidate < cheapest or (is_equal_approx(candidate, cheapest) and (current.is_empty() or str(key) < current)):
                cheapest = candidate
                current = key
        if current.is_empty() or current == destination:
            break
        visited[current] = true
        var neighbors: Array = (edges[current] as Dictionary).keys()
        neighbors.sort()
        for neighbor in neighbors:
            var alternate: float = cheapest + float(edges[current][neighbor])
            if alternate < float(costs.get(neighbor, INF)) - 0.001:
                costs[neighbor] = alternate
                previous[neighbor] = current
    if not costs.has(destination):
        return {"ok": false, "reason": "disconnected", "points": PackedVector3Array()}
    var reverse_keys: Array[String] = []
    var cursor: String = destination
    reverse_keys.append(cursor)
    while cursor != source:
        if not previous.has(cursor):
            return {"ok": false, "reason": "disconnected", "points": PackedVector3Array()}
        cursor = str(previous[cursor])
        reverse_keys.append(cursor)
    reverse_keys.reverse()
    var route := PackedVector3Array()
    route.append(start)
    for key in reverse_keys:
        var node: Vector3 = nodes[key]
        if _horizontal_distance(route[route.size() - 1], node) > NEAR_EPS:
            route.append(node)
    if _horizontal_distance(route[route.size() - 1], goal) > NEAR_EPS:
        route.append(goal)
    var length: float = 0.0
    for i in range(1, route.size()):
        length += _horizontal_distance(route[i - 1], route[i])
    return {"ok": true, "points": route, "distance_m": length,
        "direct_m": _horizontal_distance(start, goal), "street_nodes": reverse_keys.size()}

static func _horizontal_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()
