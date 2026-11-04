class_name CivicLaneRouter
extends RefCounted
## Deterministic A* over a validated directed lane graph.
## Cost is traversal time in seconds, with optional nonnegative penalties.

const EPSILON: float = 0.000001

var graph: CivicRoadGraph

func _init(road_graph: CivicRoadGraph) -> void:
    graph = road_graph

func find_route(start_id: int, goal_id: int, vehicle_mask: int, blocked_lanes: PackedInt32Array = PackedInt32Array(), extra_costs: Dictionary = {}) -> Dictionary:
    if graph == null:
        return _failure("missing_graph")
    if vehicle_mask <= 0:
        return _failure("invalid_vehicle_mask")
    if not graph.validate().is_empty():
        return _failure("invalid_graph")
    var start := graph.get_lane(start_id)
    var goal := graph.get_lane(goal_id)
    if start == null or goal == null:
        return _failure("unknown_lane")
    if not _permitted(start, vehicle_mask, blocked_lanes) or not _permitted(goal, vehicle_mask, blocked_lanes):
        return _failure("restricted_endpoint")
    for key in extra_costs.keys():
        var value: Variant = extra_costs[key]
        if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0:
            return _failure("invalid_extra_cost")
    if start_id == goal_id:
        return {"ok": true, "path": PackedInt32Array([start_id]), "cost_seconds": 0.0, "reason": ""}
    var open_set: Array[int] = [start_id]
    var previous: Dictionary = {}
    var g_score: Dictionary = {start_id: 0.0}
    var f_score: Dictionary = {start_id: _heuristic(start, goal)}
    while not open_set.is_empty():
        var current_id: int = _best_open_id(open_set, f_score)
        if current_id == goal_id:
            return _reconstruct(start_id, goal_id, previous, float(g_score[goal_id]))
        open_set.erase(current_id)
        for next_id in graph.outgoing_legal_lanes(current_id, vehicle_mask):
            var next_lane := graph.get_lane(next_id)
            if not _permitted(next_lane, vehicle_mask, blocked_lanes):
                continue
            var penalty: float = float(extra_costs.get(next_id, 0.0))
            var step_cost: float = next_lane.length_m() / next_lane.speed_limit_mps + penalty
            var candidate: float = float(g_score[current_id]) + step_cost
            if not g_score.has(next_id) or candidate < float(g_score[next_id]) - EPSILON:
                previous[next_id] = current_id
                g_score[next_id] = candidate
                f_score[next_id] = candidate + _heuristic(next_lane, goal)
                if not open_set.has(next_id):
                    open_set.append(next_id)
    return _failure("unreachable")

func _permitted(lane: CivicLaneData, vehicle_mask: int, blocked_lanes: PackedInt32Array) -> bool:
    return lane != null and not lane.is_wrong_way_connector and lane.is_vehicle_allowed(vehicle_mask) and not blocked_lanes.has(lane.lane_id)

func _heuristic(_lane: CivicLaneData, _goal: CivicLaneData) -> float:
    # Admissible lower bound: straight-line distance divided by fastest lane speed.
    # Lane-to-lane transitions are only allowed when endpoints meet within tolerance,
    # so using zero avoids overestimating when small connector gaps exist.
    return 0.0

func _best_open_id(open_set: Array[int], f_score: Dictionary) -> int:
    var best: int = open_set[0]
    for id in open_set:
        var candidate: float = float(f_score.get(id, INF))
        var current: float = float(f_score.get(best, INF))
        if candidate < current - EPSILON or (absf(candidate - current) <= EPSILON and id < best):
            best = id
    return best

func _reconstruct(start_id: int, goal_id: int, previous: Dictionary, cost: float) -> Dictionary:
    var reversed_path: Array[int] = [goal_id]
    var current: int = goal_id
    while current != start_id:
        if not previous.has(current):
            return _failure("broken_predecessor")
        current = int(previous[current])
        reversed_path.append(current)
    reversed_path.reverse()
    return {"ok": true, "path": PackedInt32Array(reversed_path), "cost_seconds": cost, "reason": ""}

func _failure(reason: String) -> Dictionary:
    return {"ok": false, "path": PackedInt32Array(), "cost_seconds": INF, "reason": reason}
