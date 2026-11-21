class_name CivicWorld002RoadCurves
extends RefCounted
## WORLD-002C: two real east-perimeter bends on legacy road edges.
## Existing nodes, lane IDs, intersections and checkpoint schema preserved.
const Organic = preload("res://scripts/world/organic_road_geometry.gd")
const EAST_X: float = 120.0
const SHIFT_M: float = 2.8
const WIDTH_M: float = 8.0
const SAMPLE_COUNT: int = 24
const NORTH_START := Vector3(120, 0, -120)
const NORTH_END := Vector3(120, 0, -46)
const SOUTH_START := Vector3(120, 0, 46)
const SOUTH_END := Vector3(120, 0, 120)

static func is_curve(start: Vector3, finish: Vector3) -> bool:
    return (_near(start, NORTH_START) and _near(finish, NORTH_END)) or (
        _near(start, NORTH_END) and _near(finish, NORTH_START)) or (
        _near(start, SOUTH_START) and _near(finish, SOUTH_END)) or (
        _near(start, SOUTH_END) and _near(finish, SOUTH_START))

static func _near(a: Vector3, b: Vector3) -> bool:
    return a.distance_to(b) < 0.01

static func centerline(start: Vector3, finish: Vector3) -> PackedVector3Array:
    if not is_curve(start, finish):
        return PackedVector3Array()
    var points := PackedVector3Array()
    for step in range(SAMPLE_COUNT + 1):
        var t: float = float(step) / float(SAMPLE_COUNT)
        # Positive X points outside the playable east perimeter. Bend
        # inward only, with zero tangent change at each old junction.
        var shift: float = SHIFT_M * pow(sin(PI * t), 2.0)
        points.append(start.lerp(finish, t) + Vector3(-shift, 0, 0))
    return points

static func driving_lane(start: Vector3, finish: Vector3,
        shoulder: float = 1.25) -> PackedVector3Array:
    var points: PackedVector3Array = centerline(start, finish)
    var result := PackedVector3Array()
    if points.size() < 2:
        return result
    for i in range(points.size()):
        var point: Vector3 = points[i]
        if i == 0 or i == points.size() - 1:
            result.append(point)
            continue
        var tangent: Vector3 = (points[i + 1] - points[i - 1]).normalized()
        var left: Vector3 = Vector3(tangent.z, 0, -tangent.x)
        var portion: float = minf(1.0, minf(
            float(i) * (finish - start).length() / float(SAMPLE_COUNT) / 4.0,
            float(SAMPLE_COUNT - i) * (finish - start).length() /
                float(SAMPLE_COUNT) / 4.0))
        result.append(point + left * shoulder * portion)
    return result

static func asphalt_mesh(start: Vector3, finish: Vector3) -> ArrayMesh:
    # Exactly the same sampled road polyline as the network/map.
    return Organic.surface_mesh(centerline(start, finish), WIDTH_M)

static func valid_geometry() -> bool:
    for section in [
        [NORTH_START, NORTH_END], [SOUTH_START, SOUTH_END]
    ]:
        var start: Vector3 = section[0]
        var finish: Vector3 = section[1]
        var line: PackedVector3Array = centerline(start, finish)
        if line.size() != SAMPLE_COUNT + 1 or line[0] != start or (
                line[line.size() - 1] != finish):
            return false
        for point in line:
            if not point.is_finite() or point.x < EAST_X - SHIFT_M - 0.01 or (
                    point.x > EAST_X + 0.01):
                return false
    return true
