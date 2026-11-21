class_name CivicMapDistricts
extends RefCounted
## MAP-002B: decorative, bounded map districts tied to existing landmarks.
## Shapes do NOT define new streets, district gameplay, routes or services.
const LivingZones = preload("res://scripts/world/living_city_zones.gd")
const ROAD_CLEARANCE_M: float = 5.0
const DISTRICT_FILL := Color(0.16, 0.27, 0.25, 0.46)
const PARK_FILL := Color(0.18, 0.36, 0.25, 0.56)
const MARKET_FILL := Color(0.32, 0.24, 0.18, 0.52)
const SERVICE_FILL := Color(0.19, 0.27, 0.38, 0.47)

## World X/Z polygons stay within existing non-road block interiors.
## Map regions are illustrative neighborhoods, not new playable geometry.
const REGIONS := [
    {"id": "garden", "label": "GARDEN QUARTER",
        "center": Vector3(13, 0, -33),
        "fill": PARK_FILL, "bounds": Rect2(6, -40, 34, 34)},
    {"id": "kiosk", "label": "KIOSK SQUARE",
        "center": Vector3(33, 0, 13),
        "fill": DISTRICT_FILL, "bounds": Rect2(6, 6, 34, 16)},
    {"id": "solar", "label": "SOLAR WARD",
        "center": Vector3(-33, 0, 13),
        "fill": DISTRICT_FILL, "bounds": Rect2(-40, 6, 34, 34)},
    {"id": "south", "label": "SOUTH MARKET",
        "center": Vector3(11, 0, 31.5),
        "fill": MARKET_FILL, "bounds": Rect2(6, 25, 34, 15)},
    {"id": "bus_stop", "label": "OLD BUS STOP",
        "center": Vector3(-92, 0, 11),
        "fill": SERVICE_FILL, "bounds": Rect2(-104, 6, 23, 16)},
    {"id": "parking", "label": "PUBLIC PARKING",
        "center": Vector3(95, 0, 92),
        "fill": SERVICE_FILL, "bounds": Rect2(83, 79, 25, 27)}
]
## Existing 3D details: OldBusStopIdentity at (-92,11) and
## ParkingCourtIdentity at (95,92). Existing GAME-025 zones remain unchanged.
const SERVICES := [
    {"id": "bus_stop", "title": "Old Bus Stop",
        "position": Vector3(-92, 0, 11), "symbol": "B"},
    {"id": "parking", "title": "Public Parking",
        "position": Vector3(95, 0, 92), "symbol": "P"}
]

static func regions() -> Array[Dictionary]:
    return REGIONS.duplicate(true)

static func services() -> Array[Dictionary]:
    return SERVICES.duplicate(true)

static func polygon(region: Dictionary) -> PackedVector3Array:
    var rect: Rect2 = region["bounds"]
    var min_x: float = rect.position.x
    var max_x: float = rect.end.x
    var min_z: float = rect.position.y
    var max_z: float = rect.end.y
    var bevel: float = minf(3.0, minf(rect.size.x, rect.size.y) * 0.16)
    return PackedVector3Array([
        Vector3(min_x + bevel, 0, min_z),
        Vector3(max_x - bevel, 0, min_z),
        Vector3(max_x, 0, min_z + bevel),
        Vector3(max_x, 0, max_z - bevel),
        Vector3(max_x - bevel, 0, max_z),
        Vector3(min_x + bevel, 0, max_z),
        Vector3(min_x, 0, max_z - bevel),
        Vector3(min_x, 0, min_z + bevel)
    ])

static func validate() -> bool:
    var seen: Dictionary = {}
    for region in REGIONS:
        var id: String = str(region["id"])
        var rect: Rect2 = region["bounds"]
        var center: Vector3 = region["center"]
        if id.is_empty() or seen.has(id) or not center.is_finite() or (
                rect.size.x <= 0 or rect.size.y <= 0):
            return false
        seen[id] = true
        if not rect.has_point(Vector2(center.x, center.z)):
            return false
        # Exclude the canonical 8m roadway and junction turn clearance.
        for axis in [-120.0, -46.0, 0.0, 46.0, 120.0]:
            if rect.position.x < axis + ROAD_CLEARANCE_M and (
                    rect.end.x > axis - ROAD_CLEARANCE_M):
                return false
            if rect.position.y < axis + ROAD_CLEARANCE_M and (
                    rect.end.y > axis - ROAD_CLEARANCE_M):
                return false
    for entry in LivingZones.LOCATIONS:
        var found: bool = false
        for region in REGIONS:
            if str(region["id"]) == str(entry["id"]) and (
                    (region["center"] as Vector3).distance_to(entry["position"]) < 0.01):
                found = true
                break
        if not found:
            return false
    return true

static func project_polygon(region: Dictionary, project: Callable) -> PackedVector2Array:
    var points := PackedVector2Array()
    for vertex in polygon(region):
        var projected: Vector2 = project.call(vertex)
        if not projected.is_finite():
            return PackedVector2Array()
        points.append(projected)
    return points

static func visible(points: PackedVector2Array, area: Rect2) -> bool:
    if points.size() < 3 or not area.has_area():
        return false
    var minimum := points[0]
    var maximum := points[0]
    for point in points:
        minimum = minimum.min(point)
        maximum = maximum.max(point)
    return Rect2(minimum, maximum - minimum).intersects(area, true)

static func closest_region(at: Vector3) -> Dictionary:
    for region in REGIONS:
        var rect: Rect2 = region["bounds"]
        if rect.has_point(Vector2(at.x, at.z)):
            return region.duplicate(true)
    return {}
