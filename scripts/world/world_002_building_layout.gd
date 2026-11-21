class_name CivicWorld002BuildingLayout
extends RefCounted
## WORLD-002A: deterministic city-block infill. Existing traffic roads,
## lane IDs, discovery anchors and road centerlines are unchanged.
const AXES: Array[float] = [-120.0, -46.0, 0.0, 46.0, 120.0]
const BASES: Array[float] = [-72.0, -24.0, 24.0, 72.0]
const ROAD_CLEARANCE_M: float = 7.0

## The outer 16 building slots retain their original node names, and the
## existing community park still occupies row=1/column=2.
static func building(row: int, column: int, base_height: float) -> Dictionary:
    if row < 0 or row >= BASES.size() or column < 0 or column >= BASES.size():
        return {}
    if row == 1 and column == 2:
        return {}
    var seed: int = row * 17 + column * 31
    var x_offset: float = [-2.5, 1.2, 2.6, -1.5][seed % 4]
    var z_offset: float = [2.2, -1.8, 1.0, -2.6][(seed / 2) % 4]
    var width: float = [8.8, 10.6, 11.8, 9.7][seed % 4]
    var depth: float = [10.7, 8.9, 11.5, 9.4][(seed + row) % 4]
    var floors: float = [0.85, 1.4, 1.05, 1.8, 1.15][(seed + column) % 5]
    var height: float = base_height * floors
    var style: String = ["market", "residential", "civic", "mixed"][(row + column) % 4]
    return {"row": row, "column": column,
        "name": "OuterBuilding_%d_%d" % [row, column],
        "center": Vector3(BASES[column] + x_offset, height * 0.5,
            BASES[row] + z_offset),
        "size": Vector3(width, height, depth),
        "style": style}

## Validate entire real collider footprint, not just the center.
## A 7m buffer around existing roads protects vehicle turns and walkers.
static func clear_of_roads(layout: Dictionary) -> bool:
    if layout.is_empty():
        return false
    var center: Vector3 = layout.get("center", Vector3.INF)
    var size: Vector3 = layout.get("size", Vector3.ZERO)
    if not center.is_finite() or not size.is_finite() or (
            size.x < 6.0 or size.z < 6.0 or size.y <= 0.0):
        return false
    for axis in AXES:
        if absf(center.x - axis) - size.x * 0.5 < ROAD_CLEARANCE_M:
            return false
        if absf(center.z - axis) - size.z * 0.5 < ROAD_CLEARANCE_M:
            return false
    return true

static func all_buildings(base_height: float = 8.0) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for row in range(BASES.size()):
        for column in range(BASES.size()):
            if row == 1 and column == 2:
                continue
            result.append(building(row, column, base_height))
    return result

static func valid_layout(base_height: float = 8.0) -> bool:
    var placed: Dictionary = {}
    for building_data in all_buildings(base_height):
        if not clear_of_roads(building_data):
            return false
        var id: String = str(building_data["name"])
        if placed.has(id):
            return false
        placed[id] = true
    return placed.size() == 15
