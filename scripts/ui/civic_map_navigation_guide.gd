class_name CivicMapNavigationGuide
extends RefCounted
## MAP-002C: presentation-only GPS cues from existing on-foot map routes.
## Never controls traffic dispatch, vehicle AI, or gameplay mission state.
const ARRIVAL_M: float = 7.0
const TURN_MIN_DEGREES: float = 28.0
const CUE_DISTANCE_M: float = 45.0

static func distance_2d(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()

static func nearest_segment_index(path: PackedVector3Array, position: Vector3) -> int:
    if path.size() < 2 or not position.is_finite():
        return -1
    var best: float = INF
    var closest: int = -1
    for i in range(path.size() - 1):
        var a := Vector2(path[i].x, path[i].z)
        var b := Vector2(path[i + 1].x, path[i + 1].z)
        var p := Vector2(position.x, position.z)
        var delta: Vector2 = b - a
        var fraction: float = clampf((p - a).dot(delta) /
            maxf(delta.length_squared(), 0.00001), 0.0, 1.0)
        var metric: float = p.distance_squared_to(a + delta * fraction)
        if metric < best:
            best = metric
            closest = i
    return closest

static func guidance(route: Dictionary, position: Vector3) -> Dictionary:
    if not bool(route.get("ok", false)) or not position.is_finite():
        return {"available": false, "instruction": "Select a destination"}
    var path: PackedVector3Array = route.get("points", PackedVector3Array())
    if path.size() < 2:
        return {"available": false, "instruction": "Route unavailable"}
    var segment: int = nearest_segment_index(path, position)
    if segment < 0:
        return {"available": false, "instruction": "Route unavailable"}
    var a := Vector2(path[segment].x, path[segment].z)
    var b := Vector2(path[segment + 1].x, path[segment + 1].z)
    var p := Vector2(position.x, position.z)
    var axis: Vector2 = b - a
    var fraction: float = clampf((p - a).dot(axis) /
        maxf(axis.length_squared(), 0.00001), 0.0, 1.0)
    var snapped: Vector2 = a + axis * fraction
    var remaining: float = snapped.distance_to(b)
    for j in range(segment + 2, path.size()):
        remaining += distance_2d(path[j - 1], path[j])
    var off_route: float = p.distance_to(snapped)
    if distance_2d(position, path[path.size() - 1]) <= ARRIVAL_M:
        return {"available": true, "instruction": "Destination reached",
            "remaining_m": 0.0, "off_route_m": off_route, "turn": "arrive"}
    if off_route > 22.0:
        return {"available": true, "instruction": "Return to highlighted route",
            "remaining_m": remaining, "off_route_m": off_route, "turn": "rejoin"}
    var direction: String = "straight"
    var instruction: String = "Continue along route"
    var to_turn: float = snapped.distance_to(b)
    if segment + 2 < path.size() and to_turn <= CUE_DISTANCE_M:
        var next_axis: Vector2 = Vector2(path[segment + 2].x - path[segment + 1].x,
            path[segment + 2].z - path[segment + 1].z)
        if axis.length_squared() > 0.0001 and next_axis.length_squared() > 0.0001:
            var angle: float = rad_to_deg(axis.angle_to(next_axis))
            if absf(angle) >= TURN_MIN_DEGREES:
                direction = "right" if angle > 0.0 else "left"
                instruction = "Turn %s in %d m" % [direction, int(roundf(to_turn))]
    return {"available": true, "instruction": instruction,
        "remaining_m": remaining, "off_route_m": off_route, "turn": direction}

static func marker_color(kind: String) -> Color:
    match kind:
        "mission":
            return Color(1.0, 0.72, 0.20)
        "service":
            return Color(0.28, 0.63, 0.83)
        "explore":
            return Color(0.36, 0.85, 0.55)
        _:
            return Color(0.94, 0.96, 0.98)

## Tap only real grounded location markers; never turn arbitrary empty
## road space into an unvalidated gameplay target.
static func nearest_marker(tap: Vector2, markers: Array[Dictionary],
        project: Callable, max_distance_px: float = 18.0) -> int:
    if not tap.is_finite():
        return -1
    var nearest: int = -1
    var metric: float = max_distance_px * max_distance_px
    for index in range(markers.size()):
        var world: Variant = markers[index].get("position")
        if not (world is Vector3):
            continue
        var pixel: Vector2 = project.call(world)
        if not pixel.is_finite():
            continue
        var distance: float = tap.distance_squared_to(pixel)
        if distance < metric:
            metric = distance
            nearest = index
    return nearest
