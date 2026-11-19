class_name CivicResponderHoldTelemetry
extends RefCounted
## TRF-003 — bounded, read-only responder traffic hold diagnostics.
##
## Usage: create one instance per municipal responder. Gameplay/Master may
## call evaluate(adapter, from_position, to_position, traffic_tick) instead
## of calling adapter.allows_step directly. Its returned permission is
## EXACTLY the Traffic adapter's result; diagnostics never grant entry,
## alter lights/reservations, modify the van, or move/despawn road users.
##
## With no adapter, movement is denied. A sampled reason is for UI/logging,
## not control flow. The diagnostic classifier runs only on state changes or
## once per SAMPLE_PERIOD_TICKS. Normal calls do not create a sample or
## allocate a temporary vehicle. Read snapshot() only when displaying UI.
const CentralPriority = preload("res://scripts/traffic/central_intersection_priority.gd")
const SAMPLE_PERIOD_TICKS: int = 20
const MAX_SAMPLES: int = 24
const MAX_TICK: int = 1000000000

var _samples: Array[Dictionary] = []
var _last_reason: String = "no_adapter"
var _last_allowed: bool = false
var _last_adapter_present: bool = false
var _last_context_valid: bool = false
var _last_sample_tick: int = -SAMPLE_PERIOD_TICKS
var _observed_steps: int = 0
var _denied_steps: int = 0

## Stable reason codes:
## clear, no_adapter, stale_route_context, invalid_motion,
## missing_signal, red_signal, pedestrian_crossing,
## central_outbound_blocked, central_zone_occupied.
func evaluate(adapter: CivicResponderStepPermission,
        from_position: Vector3, to_position: Vector3, traffic_tick: int) -> bool:
    var usable: bool = adapter != null and is_instance_valid(adapter)
    var context_valid: bool = usable and adapter._context_valid
    var allowed: bool = usable and adapter.allows_step(from_position, to_position)
    _observed_steps = mini(_observed_steps + 1, MAX_TICK)
    if not allowed:
        _denied_steps = mini(_denied_steps + 1, MAX_TICK)
    # No expensive classification on every physics frame. But always sample
    # a change between permitted and held immediately for responsive UI.
    var due: bool = _samples.is_empty() or allowed != _last_allowed or (\n        usable != _last_adapter_present) or (context_valid != _last_context_valid) or (
        traffic_tick >= _last_sample_tick + SAMPLE_PERIOD_TICKS)
    if due:
        var reason: String = "clear" if allowed else _classify(adapter, from_position, to_position)
        if _samples.is_empty() or reason != _last_reason or allowed != _last_allowed or (
                traffic_tick >= _last_sample_tick + SAMPLE_PERIOD_TICKS):
            _record(maxi(0, traffic_tick), allowed, reason)
        _last_reason = reason
        _last_sample_tick = maxi(0, traffic_tick)
    _last_allowed = allowed
    _last_adapter_present = usable
    _last_context_valid = context_valid
    return allowed

func _classify(adapter: CivicResponderStepPermission,
        from_position: Vector3, to_position: Vector3) -> String:
    if adapter == null or not is_instance_valid(adapter):
        return "no_adapter"
    if not adapter._context_valid or not is_instance_valid(adapter._spawner) or adapter._spawner.road_graph == null:
        return "stale_route_context"
    if not from_position.is_finite() or not to_position.is_finite() or (
            from_position.distance_to(to_position) > CivicResponderStepPermission.MAX_PROPOSED_STEP_M):
        return "invalid_motion"
    if adapter._index < 0 or adapter._index >= adapter._route.size():
        return "stale_route_context"
    var graph: CivicRoadGraph = adapter._spawner.road_graph
    var lane: CivicLaneData = graph.get_lane(adapter._route[adapter._index])
    if lane == null:
        return "stale_route_context"
    var projection: Dictionary = CivicResponderStepPermission._project(lane, from_position)
    if float(projection["lateral_m"]) > CivicResponderStepPermission.POSITION_TOLERANCE_M or (
            absf(float(projection["distance_m"]) - adapter._distance_m) > CivicResponderStepPermission.PROGRESS_TOLERANCE_M):
        return "stale_route_context"
    if not CentralPriority.is_inbound(lane):
        return "invalid_motion"
    var stop_distance: float = maxf(0.0, lane.length_m() - CentralPriority.STOP_LINE_M)
    var finish: Dictionary = CivicResponderStepPermission._project(lane, to_position)
    if float(projection["distance_m"]) > stop_distance + 0.01 or (
            float(finish["distance_m"]) < stop_distance - CivicResponderStepPermission.STOP_APPROACH_WINDOW_M):
        return "invalid_motion"
    var spawner: CivicTrafficSpawner = adapter._spawner
    var approach: String = spawner.signal_approach_for_lane(lane, spawner.city_mode)
    if approach.is_empty() or spawner.traffic_signals == null:
        return "missing_signal"
    # Reuse the SAME hold policy as the Traffic spawner. This temporary
    # node has no scene/physics registration and is freed immediately.
    # Only constructed on a diagnostic sampling tick, never each step.
    var service := CivicVehicleAgent.new()
    service.route = adapter._route.duplicate()
    service.current_route_index = adapter._index
    service.lane_distance_m = minf(float(projection["distance_m"]), stop_distance)
    service.active = true
    var code: String = spawner.municipal_service_hold_reason(service)
    service.free()
    if code == "red_signal" or code == "pedestrian_crossing" or (
            code == "central_outbound_blocked") or code == "central_zone_occupied":
        return code
    return "invalid_motion"

func _record(tick: int, allowed: bool, reason: String) -> void:
    if _samples.size() >= MAX_SAMPLES:
        _samples.pop_front()
    _samples.append({"tick": tick, "allowed": allowed, "reason": reason})

## Snapshot is a detached, bounded copy suitable for UI/diagnostics.
func snapshot() -> Dictionary:
    return {
        "reason": _last_reason,
        "allowed": _last_allowed,
        "sample_count": _samples.size(),
        "observed_steps": _observed_steps,
        "denied_steps": _denied_steps,
        "samples": _samples.duplicate(true)
    }

func reset() -> void:
    _samples.clear()
    _last_reason = "no_adapter"
    _last_allowed = false
    _last_adapter_present = false
    _last_context_valid = false
    _last_sample_tick = -SAMPLE_PERIOD_TICKS
    _observed_steps = 0
    _denied_steps = 0
