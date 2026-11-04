class_name CivicVehicleBehavior
extends RefCounted
## Hierarchical vehicle behavior: navigation, junction access, recovery.

enum State { ROUTING, APPROACH, WAITING, CROSSING, RECOVERY, COMPLETE }
var state: State = State.ROUTING
var reason: String = ""
var vehicle: CivicVehicleAgent
var reservations: CivicIntersectionReservations
var vehicle_id: int = -1
var junction_zone: String = "center"
var stop_distance_m: float = 3.0
var reservation_ticks: int = 200
var _owns_zone: bool = false

func configure(agent: CivicVehicleAgent, manager: CivicIntersectionReservations, id: int) -> bool:
    if agent == null or manager == null or id < 0:
        return false
    vehicle = agent
    reservations = manager
    vehicle_id = id
    _owns_zone = false
    state = State.ROUTING
    reason = ""
    return true

func advance_fixed(tick: int, _delta: float, signal_green: bool) -> void:
    if vehicle == null or reservations == null:
        state = State.RECOVERY
        reason = "missing_dependencies"
        return
    if state == State.COMPLETE or state == State.RECOVERY:
        return
    if vehicle.route.is_empty() or vehicle.road_graph == null:
        _recover("invalid_route")
        return
    if not vehicle.active:
        _finish()
        return
    if state == State.ROUTING:
        if vehicle.route.size() < 2:
            _recover("missing_junction_route")
            return
        state = State.APPROACH
    if state == State.APPROACH:
        if vehicle.current_route_index > 0:
            state = State.CROSSING
        else:
            var lane := vehicle.road_graph.get_lane(vehicle.route[0])
            if lane == null:
                _recover("lane_removed")
                return
            if lane.length_m() - vehicle.lane_distance_m <= stop_distance_m:
                state = State.WAITING
    if state == State.WAITING:
        vehicle.stop_requested = true
        if not signal_green:
            reason = "red_signal"
            return
        var result := reservations.request(vehicle_id, PackedStringArray([junction_zone]), tick, tick + reservation_ticks)
        if not result["granted"]:
            reason = str(result["reason"])
            return
        if not reservations.occupy(vehicle_id, junction_zone):
            reason = "occupancy_denied"
            return
        _owns_zone = true
        vehicle.stop_requested = false
        reason = ""
        state = State.CROSSING
    if state == State.CROSSING:
        vehicle.stop_requested = false
        if vehicle.current_route_index > 0:
            if _owns_zone:
                reservations.release(vehicle_id, junction_zone)
                _owns_zone = false
            state = State.APPROACH
            # Already past the intersection; continue toward route completion.
        if not vehicle.active:
            _finish()

func interrupt(message: String = "interrupted") -> void:
    _recover(message)

func _recover(message: String) -> void:
    if vehicle != null:
        vehicle.stop_requested = true
    if reservations != null and vehicle_id >= 0:
        if _owns_zone:
            reservations.release(vehicle_id, junction_zone)
            _owns_zone = false
        reservations.cancel(vehicle_id)
    reason = message
    state = State.RECOVERY

func _finish() -> void:
    if _owns_zone:
        reservations.release(vehicle_id, junction_zone)
        _owns_zone = false
    reservations.cancel(vehicle_id)
    state = State.COMPLETE
    reason = ""

func state_name() -> String:
    return ["routing", "approach", "waiting", "crossing", "recovery", "complete"][int(state)]
