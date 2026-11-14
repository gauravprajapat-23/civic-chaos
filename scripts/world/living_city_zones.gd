class_name CivicLivingCityZones
extends RefCounted
## GAME-025-03 — non-authoritative, offline neighborhood destinations.
## Shared by visual signposts, map routing and discovery. All markers are
## placed on existing walking-area locations, not the driving lanes.
const LOCATIONS: Array[Dictionary] = [
    {"id": "garden", "title": "Community Garden", "description": "Visit the public planting area.", "position": Vector3(13.0, 0.0, -33.0), "color": Color(0.28, 0.76, 0.43)},
    {"id": "kiosk", "title": "Community Kiosk", "description": "Explore the neighborhood information point.", "position": Vector3(33.0, 0.0, 13.0), "color": Color(0.25, 0.68, 0.88)},
    {"id": "solar", "title": "Solar Corner", "description": "Discover the solar lighting demonstration.", "position": Vector3(-33.0, 0.0, 13.0), "color": Color(0.97, 0.76, 0.24)},
    {"id": "south", "title": "South Market Walk", "description": "Explore the south market sidewalk.", "position": Vector3(11.0, 0.0, 31.5), "color": Color(0.90, 0.56, 0.34)}
]
const DISCOVERY_RADIUS_M: float = 5.0

static func all() -> Array[Dictionary]:
    return LOCATIONS.duplicate(true)

static func by_id(id: String) -> Dictionary:
    for entry in LOCATIONS:
        if str(entry["id"]) == id:
            return entry.duplicate(true)
    return {}

static func nearby(at: Vector3) -> Array[String]:
    var result: Array[String] = []
    if not at.is_finite():
        return result
    for entry in LOCATIONS:
        var target: Vector3 = entry["position"]
        var distance: Vector2 = Vector2(at.x - target.x, at.z - target.z)
        if distance.length_squared() <= DISCOVERY_RADIUS_M * DISCOVERY_RADIUS_M:
            result.append(str(entry["id"]))
    return result

static func valid_layout() -> bool:
    var seen: Dictionary = {}
    for entry in LOCATIONS:
        var id: String = str(entry.get("id", ""))
        var position: Vector3 = entry.get("position", Vector3.INF)
        if id.is_empty() or seen.has(id) or not position.is_finite():
            return false
        seen[id] = true
        # The layout's 8m roads follow X/Z = 0, ±46 and ±120.
        # These destinations must stay outside the driving surface.
        for axis in [-120.0, -46.0, 0.0, 46.0, 120.0]:
            if absf(position.x - axis) < 5.0 or absf(position.z - axis) < 5.0:
                return false
    return true
