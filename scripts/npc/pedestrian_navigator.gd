class_name CivicPedestrianNavigator
extends Node3D
## Fixed-tick sidewalk waypoint traversal with exclusive crosswalk access.

enum State { IDLE, WALKING, WAITING, CROSSING, COMPLETE, BLOCKED }
var state: State = State.IDLE
var route: PackedVector3Array = PackedVector3Array()
var crossing_segment: int = -1
var waypoint_index: int = 1
var speed_mps: float = 1.4
var pedestrian_id: int = -1
var zone: String = "crosswalk"
var reservations: CivicIntersectionReservations
var reason: String = ""
var _owns_zone: bool = false

func configure(id: int, waypoints: PackedVector3Array, cross_segment: int, manager: CivicIntersectionReservations) -> bool:
    _release_zone()
    if id < 0 or manager == null or waypoints.size() < 2 or cross_segment < 0 or cross_segment >= waypoints.size() - 1 or not is_finite(speed_mps) or speed_mps <= 0.0:
        state = State.BLOCKED
        reason = "invalid_route"
        return false
    for point in waypoints:
        if not point.is_finite():
            state = State.BLOCKED
            reason = "invalid_waypoint"
            return false
    pedestrian_id = id
    route = waypoints.duplicate()
    crossing_segment = cross_segment
    reservations = manager
    waypoint_index = 1
    global_position = route[0]
    state = State.WAITING if cross_segment == 0 else State.WALKING
    reason = ""
    return true

func advance_fixed(tick: int, delta: float, pedestrian_green: bool, vehicle_clear: bool) -> void:
    if state == State.BLOCKED or state == State.COMPLETE or state == State.IDLE:
        return
    if delta <= 0.0 or not is_finite(delta) or reservations == null:
        return
    if state == State.WAITING:
        if not pedestrian_green or not vehicle_clear:
            reason = "crossing_not_permitted"
            return
        var result := reservations.request(pedestrian_id, PackedStringArray([zone]), tick, tick + 200)
        if not result["granted"] or not reservations.occupy(pedestrian_id, zone):
            reason = "crosswalk_occupied"
            return
        _owns_zone = true
        state = State.CROSSING
        reason = ""
    var target: Vector3 = route[waypoint_index]
    global_position = global_position.move_toward(target, speed_mps * delta)
    if global_position.distance_to(target) <= 0.0001:
        waypoint_index += 1
        if state == State.CROSSING:
            _release_zone()
        if waypoint_index >= route.size():
            state = State.COMPLETE
        elif waypoint_index - 1 == crossing_segment:
            state = State.WAITING
        else:
            state = State.WALKING

func interrupt(message: String = "interrupted") -> void:
    _release_zone()
    state = State.BLOCKED
    reason = message

func _release_zone() -> void:
    if reservations != null and pedestrian_id >= 0:
        if _owns_zone:
            reservations.release(pedestrian_id, zone)
        reservations.cancel(pedestrian_id)
    _owns_zone = false

func state_name() -> String:
    return ["idle", "walking", "waiting", "crossing", "complete", "blocked"][int(state)]
