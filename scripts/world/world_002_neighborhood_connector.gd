class_name CivicWorld002NeighborhoodConnector
extends RefCounted
## WORLD-002C2: a real, connected northeastern neighborhood loop.
## New lanes begin at 1000. Historic lane IDs 100..179 never change.
const LegacyRoad = preload("res://scripts/world/organic_road_geometry.gd")
const BuildLayout = preload("res://scripts/world/world_002_building_layout.gd")
const Squares = preload("res://scripts/world/world_002_public_spaces.gd")
const JUNCTION := Vector3(83.0, 0.0, -106.0)
const WEST := Vector3(46.0, 0.0, -120.0)
const EAST := Vector3(120.0, 0.0, -120.0)
const WIDTH_M: float = 6.0
const SHOULDER_M: float = 1.30
const SAMPLES: int = 12
const CONNECTOR_ID := "world002:ne-loop"
const LANE_FIRST: int = 1000

static func nodes() -> Array[Dictionary]:
    return [{"id": CONNECTOR_ID, "position": JUNCTION,
        "junction_form": "corner", "junction_type": "legacy_outer_controlled"}]

static func road_definitions() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for i in range(2):
        var start: Vector3 = WEST if i == 0 else JUNCTION
        var finish: Vector3 = JUNCTION if i == 0 else EAST
        var id: int = LANE_FIRST + i * 2
        result.append({"id": "road:%d" % id,
            "from_node": "3:0" if i == 0 else CONNECTOR_ID,
            "to_node": CONNECTOR_ID if i == 0 else "4:0",
            "start": start, "end": finish,
            "centerline": centerline(start, finish),
            "organic_pilot": false, "world_002_curve": false,
            "world_002_connector": true,
            "lane_forward": id, "lane_reverse": id + 1,
            "width_m": WIDTH_M,
            "speed_limit_mps": 4.0,
            "road_type": "collector", "challenge": false,
            "vehicle_access": true})
    return result

static func centerline(start: Vector3, finish: Vector3) -> PackedVector3Array:
    var points := PackedVector3Array()
    for step in range(SAMPLES + 1):
        var t: float = float(step) / float(SAMPLES)
        # Retain the original junction endpoints and connect both segments
        # through the explicit NE junction. No visual-only road shortcuts.
        points.append(start.lerp(finish, t))
    return points

static func driving_lane(start: Vector3, finish: Vector3) -> PackedVector3Array:
    var road: PackedVector3Array = centerline(start, finish)
    var lane := PackedVector3Array()
    var forward: Vector3 = (finish - start).normalized()
    var left := Vector3(forward.z, 0.0, -forward.x)
    var length_m: float = start.distance_to(finish)
    for i in range(road.size()):
        var t: float = float(i) / float(SAMPLES)
        var fade: float = minf(1.0, minf(t * length_m / 4.0,
            (1.0 - t) * length_m / 4.0))
        lane.append(road[i] + left * SHOULDER_M * fade)
    return lane

static func asphalt_mesh(start: Vector3, finish: Vector3) -> ArrayMesh:
    return LegacyRoad.surface_mesh(centerline(start, finish), WIDTH_M)

static func _line_clear_of_rect(start: Vector3, finish: Vector3,
        bounds: Rect2, clearance: float) -> bool:
    # Sample densely enough to verify actual 6m asphalt against all
    # known building footprints and the existing public-square bounds.
    for i in range(101):
        var sample: Vector3 = start.lerp(finish, float(i) / 100.0)
        var nearest := Vector2(clampf(sample.x, bounds.position.x, bounds.end.x),
            clampf(sample.z, bounds.position.y, bounds.end.y))
        if Vector2(sample.x, sample.z).distance_to(nearest) < clearance:
            return false
    return true

static func valid_clearances() -> bool:
    for road in road_definitions():
        var start: Vector3 = road["start"]
        var finish: Vector3 = road["end"]
        # Six-metre ribbon plus a 1m safety margin, excluding known
        # endpoint intersections on the pre-existing northern road.
        for item in BuildLayout.all_buildings():
            var center: Vector3 = item["center"]
            var size: Vector3 = item["size"]
            var bounds := Rect2(
                Vector2(center.x - size.x * 0.5, center.z - size.z * 0.5),
                Vector2(size.x, size.z))
            if not _line_clear_of_rect(start, finish, bounds, WIDTH_M * 0.5 + 1.0):
                return false
        for plot in Squares.plots():
            if not _line_clear_of_rect(start, finish, Squares.bounds(plot),
                    WIDTH_M * 0.5 + 1.0):
                return false
    return true
