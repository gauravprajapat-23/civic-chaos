class_name CivicJunctionPriorityRules
extends RefCounted
## WORLD-001C: bounded, fail-closed gap acceptance at explicit local T nodes.
## Zero new persistent state: all decisions use live lane progress and the
## checkpoint-stable order of traffic fleet slots.
const Network = preload("res://scripts/world/city_network_definition.gd")
const LEGACY_SIGNAL: String = "legacy_outer_controlled"
const PRIORITY_T: String = "priority_t"
const STOP_LINE_M: float = 5.0
const GAP_EPS: float = 0.0001

## Only explicitly classified nodes may bypass the old timed outer lights.
## Unknown locations remain managed by the existing outer policy.
static func classification(at: Vector3) -> String:
    for node in Network.nodes():
        if (node["position"] as Vector3).distance_to(at) <= 0.05:
            return str(node.get("junction_type", LEGACY_SIGNAL))
    return ""

static func is_priority_t(at: Vector3) -> bool:
    return classification(at) == PRIORITY_T

## Through street on the west edge has priority over the branch from east.
## All movements still require an empty physical intersection and clear exit.
static func approach_rank(lane: CivicLaneData) -> int:
    if lane == null or lane.centerline.size() < 2:
        return 999
    var start: Vector3 = lane.centerline[0]
    var finish: Vector3 = lane.centerline[-1]
    var direction: Vector3 = finish - start
    return 0 if absf(direction.z) >= absf(direction.x) else 1

## Deterministic potential entrant. Never infer permission from "no
## signal" alone; a competing approaching vehicle is still a conflict.
static func first_entrant(vehicle: CivicVehicleAgent, lane: CivicLaneData,
        candidates: Array[CivicVehicleAgent], graph: CivicRoadGraph,
        junction: Vector3) -> bool:
    if vehicle == null or lane == null or graph == null or not is_priority_t(junction):
        return false
    var own_gap: float = maxf(0.0, lane.length_m() - STOP_LINE_M) - vehicle.lane_distance_m
    var own_rank: int = approach_rank(lane)
    var own_slot: int = candidates.find(vehicle)
    if own_slot < 0:
        return false
    for slot in range(candidates.size()):
        var other: CivicVehicleAgent = candidates[slot]
        if other == null or other == vehicle or not other.active or other.stop_requested:
            continue
        if other.current_route_index < 0 or other.current_route_index >= other.route.size():
            continue
        var other_lane: CivicLaneData = graph.get_lane(other.route[other.current_route_index])
        if other_lane == null or other_lane.centerline.size() < 2 or (
                other_lane.centerline[-1].distance_to(junction) > 0.05):
            continue
        var other_gap: float = maxf(0.0, other_lane.length_m() - STOP_LINE_M) - other.lane_distance_m
        # Ignore traffic too far from the junction to conflict now.
        if other_gap > 16.0 or other_gap < -GAP_EPS:
            continue
        var other_rank: int = approach_rank(other_lane)
        if other_rank < own_rank:
            return false
        if other_rank == own_rank:
            if other_gap < own_gap - GAP_EPS:
                return false
            if absf(other_gap - own_gap) <= GAP_EPS:
                if other_lane.lane_id < lane.lane_id or (
                        other_lane.lane_id == lane.lane_id and slot < own_slot):
                    return false
    return true
