class_name CivicCentralIntersectionPriority
extends RefCounted
## JUNCTION-FIX-03B: stateless entry arbitration for a central four-way
## junction. Existing traffic signals and pedestrian crossing permissions
## remain authoritative. This does NOT reprogram lights or move vehicles.
const STOP_LINE_M: float = 5.0
const EXIT_CLEARANCE_M: float = 7.0
const ENTRY_EPSILON_M: float = 0.05

static func is_inbound(lane: CivicLaneData) -> bool:
    if lane == null or lane.centerline.size() < 2:
        return false
    var endpoint: Vector3 = lane.centerline[lane.centerline.size() - 1]
    return absf(endpoint.x) <= 0.05 and absf(endpoint.z) <= 0.05

static func occupies(car: CivicVehicleAgent, graph: CivicRoadGraph) -> bool:
    if car == null or not car.active or graph == null or car.route.is_empty():
        return false
    if car.current_route_index < 0 or car.current_route_index >= car.route.size():
        return false
    var lane: CivicLaneData = graph.get_lane(car.route[car.current_route_index])
    if lane == null:
        return false
    if is_inbound(lane):
        return car.lane_distance_m > maxf(0.0, lane.length_m() - STOP_LINE_M) + ENTRY_EPSILON_M
    var origin: Vector3 = lane.centerline[0]
    return absf(origin.x) <= 0.05 and absf(origin.z) <= 0.05 and car.lane_distance_m < EXIT_CLEARANCE_M

static func disposition(car: CivicVehicleAgent, graph: CivicRoadGraph,
        fleet: Array[CivicVehicleAgent], stop_gap: float) -> Dictionary:
    if car == null or graph == null or car.route.is_empty() or car.current_route_index < 0 or car.current_route_index >= car.route.size():
        return {"yield": false, "reason": "not_applicable"}
    var lane: CivicLaneData = graph.get_lane(car.route[car.current_route_index])
    if not is_inbound(lane) or stop_gap < -ENTRY_EPSILON_M:
        return {"yield": false, "reason": "already_entered"}
    for other in fleet:
        if other != car and occupies(other, graph):
            return {"yield": true, "reason": "central_zone_occupied"}
    var own_slot: int = fleet.find(car)
    for other in fleet:
        if other == null or other == car or not other.active or other.stop_requested or other.route.is_empty():
            continue
        if other.current_route_index < 0 or other.current_route_index >= other.route.size():
            continue
        var competitor: CivicLaneData = graph.get_lane(other.route[other.current_route_index])
        if not is_inbound(competitor):
            continue
        var other_gap: float = maxf(0.0, competitor.length_m() - STOP_LINE_M) - other.lane_distance_m
        if other_gap < -ENTRY_EPSILON_M:
            continue
        if other_gap < stop_gap - 0.0001:
            return {"yield": true, "reason": "central_priority"}
        if absf(other_gap - stop_gap) <= 0.0001:
            if competitor.lane_id < lane.lane_id or (competitor.lane_id == lane.lane_id and fleet.find(other) < own_slot):
                return {"yield": true, "reason": "central_priority"}
    return {"yield": false, "reason": "granted"}
