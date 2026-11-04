# Deterministic Lane Routing — CC-007

`CivicLaneRouter.find_route(start_id, goal_id, vehicle_mask, blocked_lanes, extra_costs)` returns a dictionary:
- Success: `{ok: true, path: PackedInt32Array, cost_seconds: float, reason: ""}`
- Failure: `{ok: false, path: [], cost_seconds: INF, reason: "reason_code"}`

Routing follows directed legal connections only. It respects vehicle-class bit masks, wrong-way exclusions, blocked lane IDs and optional nonnegative per-lane congestion penalties. Traversal cost is lane length / speed limit + penalty for each *entered* lane; start lane cost is excluded because the vehicle is already on it. Invalid graphs are rejected instead of silently producing illegal paths.

The current implementation uses a zero heuristic, making A* equivalent to Dijkstra's algorithm. This preserves optimality even when connector gaps are tolerated by CC-006. Ties are broken by ascending lane ID, giving reproducible results. A future geometric heuristic can be introduced once connectors are geometrically continuous and its admissibility is proven.

Run `godot --headless --path . --script res://tests/lane_routing_test.gd` after project import. The suite checks weighted routes, restrictions, blocked lanes, unreachable destinations, invalid inputs and deterministic ties.

Performance is O(V² + E) with a linear open-set scan, appropriate for the initial prototype. A binary heap and cached graph validation can be introduced when maps become large.
