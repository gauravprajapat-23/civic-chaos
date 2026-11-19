class_name CivicResponderStepPermission
extends RefCounted
## TRF-002: read-only permission gate for a municipal van's proposed step.
##
## Ownership: Gameplay owns the van, physical sweeps and route progress.
## Traffic owns this adapter and the CivicTrafficSpawner it queries.
## Create one adapter per responder; configure(spawner), then call
## set_route_context(route_lane_ids, current_index, lane_distance_m) before
## each allows_step(from_position, to_position) call. No movement, mutation,
## signal priority, or traffic removal occurs here.
##
## Positions alone do NOT establish approach identity: the route must be a
## directed, legal sequence of real graph lane IDs. Unconfigured/stale
## context fails closed. Do not bind an always-allow callback.
const CentralPriority = preload("res://scripts/traffic/central_intersection_priority.gd")
const POSITION_TOLERANCE_M: float = 2.5
const PROGRESS_TOLERANCE_M: float = 2.5
const STOP_APPROACH_WINDOW_M: float = 2.0
const MAX_PROPOSED_STEP_M: float = 2.0

var _spawner: CivicTrafficSpawner
var _route: PackedInt32Array = PackedInt32Array()
var _index: int = -1
var _distance_m: float = -1.0
var _context_valid: bool = false

func configure(spawner: CivicTrafficSpawner) -> bool:
    _spawner = spawner
    clear_context()
    return is_instance_valid(_spawner) and _spawner.road_graph != null

func clear_context() -> void:
    _route = PackedInt32Array()
    _index = -1
    _distance_m = -1.0
    _context_valid = false

## Gameplay must update progress from its authoritative directed lane route,
## not infer a nearest green road from position alone. Route changes require
## a new context. This setter does not grant permission.
func set_route_context(route_lane_ids: PackedInt32Array,
        current_index: int, lane_distance_m: float) -> bool:
    clear_context()
    if not is_instance_valid(_spawner) or _spawner.road_graph == null:
        return false
    if route_lane_ids.is_empty() or current_index < 0 or current_index >= route_lane_ids.size():
        return false
    if not is_finite(lane_distance_m):
        return false
    var graph: CivicRoadGraph = _spawner.road_graph
    for i in range(route_lane_ids.size()):
        var lane: CivicLaneData = graph.get_lane(route_lane_ids[i])
        if lane == null or lane.is_wrong_way_connector or lane.centerline.size() < 2:
            return false
        if i > 0 and not graph.outgoing_legal_lanes(route_lane_ids[i - 1], 1).has(route_lane_ids[i]):
            return false
    var active_lane: CivicLaneData = graph.get_lane(route_lane_ids[current_index])
    if lane_distance_m < 0.0 or lane_distance_m > active_lane.length_m() + 0.01:
        return false
    _route = route_lane_ids.duplicate()
    _index = current_index
    _distance_m = lane_distance_m
    _context_valid = true
    return true

## Callback-compatible API: Callable(Vector3, Vector3) -> bool.
## No optimistic success on invalid geometry, untrusted route progress,
## ambiguous transitions, red/amber lights, pedestrian occupation, a
## committed central vehicle, or blocked downstream exit.
func allows_step(from_position: Vector3, to_position: Vector3) -> bool:
    if not _context_valid or not is_instance_valid(_spawner) or _spawner.road_graph == null:
        return false
    if not from_position.is_finite() or not to_position.is_finite():
        return false
    if from_position.distance_to(to_position) > MAX_PROPOSED_STEP_M:
        return false
    var graph: CivicRoadGraph = _spawner.road_graph
    var lane: CivicLaneData = graph.get_lane(_route[_index])
    if lane == null:
        return false
    var start: Dictionary = _project(lane, from_position)
    if float(start["lateral_m"]) > POSITION_TOLERANCE_M or absf(float(start["distance_m"]) - _distance_m) > PROGRESS_TOLERANCE_M:
        return false
    var finish: Dictionary = _project(lane, to_position)
    var finish_distance: float = float(finish["distance_m"])
    if float(finish["lateral_m"]) > POSITION_TOLERANCE_M:
        # Crossing a valid directed lane boundary is the only permitted
        # exception to matching both endpoints to this lane.
        if _index + 1 >= _route.size() or lane.length_m() - float(start["distance_m"]) > POSITION_TOLERANCE_M:
            return false
        var next_lane: CivicLaneData = graph.get_lane(_route[_index + 1])
        if next_lane == null:
            return false
        var next_projection: Dictionary = _project(next_lane, to_position)
        if float(next_projection["lateral_m"]) > POSITION_TOLERANCE_M or float(next_projection["distance_m"]) > POSITION_TOLERANCE_M:
            return false
        finish_distance = lane.length_m()
    if finish_distance + 0.1 < float(start["distance_m"]):
        return false
    if CentralPriority.is_inbound(lane):
        var stop_distance: float = maxf(0.0, lane.length_m() - CentralPriority.STOP_LINE_M)
        if float(start["distance_m"]) <= stop_distance + 0.01 and finish_distance >= stop_distance - STOP_APPROACH_WINDOW_M:
            var service := CivicVehicleAgent.new()
            service.route = _route.duplicate()
            service.current_route_index = _index
            service.lane_distance_m = minf(float(start["distance_m"]), stop_distance)
            service.active = true
            var reason: String = _spawner.municipal_service_hold_reason(service)
            service.free()
            # Junction permission requires an authoritative signal.
            # An absent controller is never an implicit green.
            if _spawner.traffic_signals == null or reason != "":
                return false
            var approach: String = _spawner.signal_approach_for_lane(lane, _spawner.city_mode)
            if approach.is_empty() or _spawner.traffic_signals.aspect_for_approach(approach) != "green":
                return false
    return true

## Polyline arclength, not nearest-lane selection; caller supplies lane ID.
static func _project(lane: CivicLaneData, position: Vector3) -> Dictionary:
    var best_lateral: float = INF
    var best_distance: float = 0.0
    var cumulative: float = 0.0
    for i in range(1, lane.centerline.size()):
        var a: Vector3 = lane.centerline[i - 1]
        var b: Vector3 = lane.centerline[i]
        var ab := Vector2(b.x - a.x, b.z - a.z)
        var ap := Vector2(position.x - a.x, position.z - a.z)
        var segment_length: float = (b - a).length()
        var parameter: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
        var lateral: float = (ap - ab * parameter).length()
        if lateral < best_lateral:
            best_lateral = lateral
            best_distance = cumulative + segment_length * parameter
        cumulative += segment_length
    return {"distance_m": best_distance, "lateral_m": best_lateral}
