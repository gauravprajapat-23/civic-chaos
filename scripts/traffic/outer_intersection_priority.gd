class_name CivicOuterIntersectionPriority
extends RefCounted
## AUD2-MAP-02 — deterministic safety for noncentral city junctions.
## Pure fixed-tick policy: no reservations to desynchronise on F5/F9.
## A single vehicle may commit to a node's conflict zone at a time.
## Existing vehicle footprint sweeps still handle physical collision.
const Grid = preload("res://scripts/world/city_road_layout.gd")
const GREEN_TICKS: int = 120
const CLEARANCE_TICKS: int = 40
const PERIOD_TICKS: int = 2 * (GREEN_TICKS + CLEARANCE_TICKS)
const STOP_LINE_M: float = 5.0
const EXIT_CLEARANCE_M: float = 7.0
const COMMITTED_EPSILON_M: float = 0.05

## Position of the controlled node; a central (0,0) intersection is
## controlled by the preexisting CivicTrafficSignalController, never here.
static func junction_for_lane(lane: CivicLaneData) -> Vector3:
    if lane == null or lane.centerline.size() < 2:
        return Vector3(INF, 0.0, INF)
    var end: Vector3 = lane.centerline[lane.centerline.size() - 1]
    if absf(end.x) <= 0.05 and absf(end.z) <= 0.05:
        return Vector3(INF, 0.0, INF)
    if not _on_axis(end.x) or not _on_axis(end.z):
        return Vector3(INF, 0.0, INF)
    return Vector3(end.x, 0.0, end.z)

static func _on_axis(value: float) -> bool:
    for coordinate in Grid.coordinates():
        if absf(value - coordinate) <= 0.05:
            return true
    return false

static func is_controlled(lane: CivicLaneData) -> bool:
    return junction_for_lane(lane).x != INF

static func axis_for_lane(lane: CivicLaneData) -> String:
    if lane == null or lane.centerline.size() < 2:
        return ""
    var direction: Vector3 = lane.centerline[lane.centerline.size() - 1] - lane.centerline[0]
    if direction.length_squared() <= 0.001:
        return ""
    return "ns" if absf(direction.z) >= absf(direction.x) else "ew"

## 20 fixed ticks/s: NS 6 s, all-red 2 s, EW 6 s, all-red 2 s.
## The two axes are NEVER simultaneously authorized. No wall-clock input.
static func aspect(axis: String, tick: int) -> String:
    if tick < 0 or (axis != "ns" and axis != "ew"):
        return "red"
    var phase: int = tick % PERIOD_TICKS
    if axis == "ns" and phase < GREEN_TICKS:
        return "green"
    if axis == "ew" and phase >= GREEN_TICKS + CLEARANCE_TICKS and phase < 2 * GREEN_TICKS + CLEARANCE_TICKS:
        return "green"
    return "red"

static func _same_node(a: Vector3, b: Vector3) -> bool:
    return absf(a.x - b.x) <= 0.05 and absf(a.z - b.z) <= 0.05

## Derive occupancy from the saved lane, route slot and distance. Crossing
## began when the front passed the upstream 5 m stop line; it clears after
## reaching 7 m along the next (outbound) lane. Thus no ObjectDB IDs or
## extra save schema are needed to preserve ownership across restores.
static func occupies(vehicle: CivicVehicleAgent, graph: CivicRoadGraph, junction: Vector3) -> bool:
    if vehicle == null or not vehicle.active or graph == null or vehicle.route.is_empty():
        return false
    if vehicle.current_route_index < 0 or vehicle.current_route_index >= vehicle.route.size():
        return false
    var lane: CivicLaneData = graph.get_lane(vehicle.route[vehicle.current_route_index])
    if lane == null or lane.centerline.size() < 2:
        return false
    var destination: Vector3 = lane.centerline[lane.centerline.size() - 1]
    if _same_node(destination, junction):
        return vehicle.lane_distance_m > maxf(0.0, lane.length_m() - STOP_LINE_M) + COMMITTED_EPSILON_M
    var origin: Vector3 = lane.centerline[0]
    return _same_node(origin, junction) and vehicle.lane_distance_m < EXIT_CLEARANCE_M

## The winner for a free approach is the car nearest its stop line;
## ties break by stable lane ID then saved fleet array order. The array is
## already the checkpoint's deterministic car-slot order.
static func disposition(vehicle: CivicVehicleAgent, graph: CivicRoadGraph, cars: Array[CivicVehicleAgent], tick: int) -> Dictionary:
    var clear := {"controlled": false, "yield": false, "reason": "uncontrolled"}
    if vehicle == null or graph == null or not vehicle.active or vehicle.route.is_empty():
        return clear
    if vehicle.current_route_index < 0 or vehicle.current_route_index >= vehicle.route.size():
        return clear
    var lane: CivicLaneData = graph.get_lane(vehicle.route[vehicle.current_route_index])
    if not is_controlled(lane):
        return clear
    var junction: Vector3 = junction_for_lane(lane)
    var stop_line: float = maxf(0.0, lane.length_m() - STOP_LINE_M)
    if vehicle.lane_distance_m > stop_line + COMMITTED_EPSILON_M:
        return {"controlled": true, "yield": false, "reason": "already_entered"}
    if aspect(axis_for_lane(lane), tick) != "green":
        return {"controlled": true, "yield": true, "reason": "red_or_clearance"}

    for other in cars:
        if other == null or other == vehicle or not other.active:
            continue
        if occupies(other, graph, junction):
            return {"controlled": true, "yield": true, "reason": "zone_occupied"}

    var own_gap: float = stop_line - vehicle.lane_distance_m
    var own_index: int = cars.find(vehicle)
    for other in cars:
        if other == null or other == vehicle or not other.active or other.route.is_empty():
            continue
        if other.current_route_index < 0 or other.current_route_index >= other.route.size():
            continue
        var other_lane: CivicLaneData = graph.get_lane(other.route[other.current_route_index])
        if not is_controlled(other_lane) or not _same_node(junction_for_lane(other_lane), junction):
            continue
        if aspect(axis_for_lane(other_lane), tick) != "green":
            continue
        var other_stop: float = maxf(0.0, other_lane.length_m() - STOP_LINE_M)
        var other_gap: float = other_stop - other.lane_distance_m
        if other_gap < own_gap - 0.0001:
            return {"controlled": true, "yield": true, "reason": "higher_priority_approach"}
        if absf(other_gap - own_gap) <= 0.0001:
            if other_lane.lane_id < lane.lane_id:
                return {"controlled": true, "yield": true, "reason": "higher_priority_lane"}
            if other_lane.lane_id == lane.lane_id and cars.find(other) < own_index:
                return {"controlled": true, "yield": true, "reason": "higher_priority_slot"}
    return {"controlled": true, "yield": false, "reason": "granted"}
