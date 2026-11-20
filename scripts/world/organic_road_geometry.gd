class_name CivicOrganicRoadGeometry
extends RefCounted
## WORLD-001B: one deterministic organic road pilot on the west perimeter.
## The pilot replaces only the (-120,-120) -> (-120,-46) segment.
## The next milestone will introduce new *drivable* T-junction branches
## with their own priority contracts; no optimistic access is granted here.
const PILOT_FROM: Vector3 = Vector3(-120, 0, -120)
const PILOT_TO: Vector3 = Vector3(-120, 0, -46)
const PILOT_WIDTH: float = 8.0
const PILOT_SHIFT: float = 2.25
const SAMPLE_COUNT: int = 24

static func is_pilot(start: Vector3, finish: Vector3) -> bool:
    return (start.distance_to(PILOT_FROM) < 0.01 and finish.distance_to(PILOT_TO) < 0.01) or (
        start.distance_to(PILOT_TO) < 0.01 and finish.distance_to(PILOT_FROM) < 0.01)

## Smooth bell-shaped curve, zero tangent and displacement at the original
## junctions. All positions remain inside the district boundary.
static func centerline() -> PackedVector3Array:
    var points := PackedVector3Array()
    for step in range(SAMPLE_COUNT + 1):
        var t: float = float(step) / float(SAMPLE_COUNT)
        var offset: float = PILOT_SHIFT * pow(sin(PI * t), 2.0)
        points.append(PILOT_FROM.lerp(PILOT_TO, t) + Vector3(offset, 0, 0))
    return points

static func reversed_centerline() -> PackedVector3Array:
    var original: PackedVector3Array = centerline()
    var reverse := PackedVector3Array()
    for i in range(original.size() - 1, -1, -1):
        reverse.append(original[i])
    return reverse

## Mid-road left-lane offset and 4m junction ramps are compatible with
## the original lane ownership and do not move existing stop-line endpoints.
static func driving_lane(start: Vector3, finish: Vector3, shoulder: float = 1.25) -> PackedVector3Array:
    var points: PackedVector3Array = centerline() if (
        start.distance_to(PILOT_FROM) < 0.01) else reversed_centerline()
    var result := PackedVector3Array()
    for index in range(points.size()):
        var point: Vector3 = points[index]
        if index == 0 or index == points.size() - 1:
            result.append(point)
            continue
        var tangent: Vector3 = (points[index + 1] - points[index - 1]).normalized()
        var left := Vector3(tangent.z, 0, -tangent.x)
        var ramp: float = minf(1.0, (float(index) * (PILOT_TO - PILOT_FROM).length() /
            float(points.size() - 1)) / 4.0)
        var back_ramp: float = minf(1.0, (float(points.size() - 1 - index) *
            (PILOT_TO - PILOT_FROM).length() / float(points.size() - 1)) / 4.0)
        result.append(point + left * shoulder * minf(ramp, back_ramp))
    return result

## Generate a ribbon of actual asphalt from the same points as traffic.
## Road render is mesh-only: existing ground supports collision; there is
## no added invisible StaticBody blocking a vehicle at the new bend.
static func surface_mesh(points: PackedVector3Array, width: float = PILOT_WIDTH) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    if points.size() < 2 or width < 3.0:
        return ArrayMesh.new()
    for i in range(points.size()):
        var tangent: Vector3
        if i == 0:
            tangent = (points[1] - points[0]).normalized()
        elif i == points.size() - 1:
            tangent = (points[i] - points[i - 1]).normalized()
        else:
            tangent = (points[i + 1] - points[i - 1]).normalized()
        var sideways := Vector3(tangent.z, 0, -tangent.x)
        var center: Vector3 = points[i] + Vector3.UP * 0.022
        vertices.append(center - sideways * width * 0.5)
        vertices.append(center + sideways * width * 0.5)
        normals.append(Vector3.UP)
        normals.append(Vector3.UP)
        var longitudinal: float = float(i) / float(points.size() - 1)
        uvs.append(Vector2(0.0, longitudinal))
        uvs.append(Vector2(1.0, longitudinal))
        if i < points.size() - 1:
            var offset: int = i * 2
            indices.append_array(PackedInt32Array([
                offset, offset + 2, offset + 1,
                offset + 1, offset + 2, offset + 3]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

## Physical edge of the actual new road; used by tests and future curbs.
static func edge_points(side: float) -> PackedVector3Array:
    var points: PackedVector3Array = centerline()
    var edge := PackedVector3Array()
    for i in range(points.size()):
        var before: Vector3 = points[maxi(0, i - 1)]
        var after: Vector3 = points[mini(points.size() - 1, i + 1)]
        var tangent: Vector3 = (after - before).normalized()
        var left := Vector3(tangent.z, 0, -tangent.x)
        edge.append(points[i] + left * PILOT_WIDTH * 0.5 * side)
    return edge
