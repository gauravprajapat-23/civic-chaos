class_name CivicCityNetworkDefinition
extends RefCounted
## WORLD-001A: deterministic, read-only *description* of existing city streets.
## This is a compatibility bridge, not a new traffic simulator. Road meshes,
## lane graphs and future MAP rendering will share these edge definitions.
## Do not reorder legacy edges or reuse their lane IDs: checkpoint traffic
## snapshots persist lane identities and distances.
const Layout = preload("res://scripts/world/city_road_layout.gd")
const Organic = preload("res://scripts/world/organic_road_geometry.gd")
const EastCurves = preload("res://scripts/world/world_002_road_curves.gd")
const NeighborhoodLink = preload("res://scripts/world/world_002_neighborhood_connector.gd")
const SCHEMA_VERSION: int = 1
const LEGACY_LANE_BASE: int = 100
const FUTURE_LANE_BASE: int = 1000
const MAIN_JUNCTION_ID: String = "2:2"
const SIGNALIZED: String = "signalized"
const LEGACY_OUTER: String = "legacy_outer_controlled"
const PRIORITY_T: String = "priority_t"
const COLLECTOR: String = "collector"
const MARKET: String = "market"

## Stable node keys are legacy grid indexes, not array iteration positions.
static func nodes() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var axes: Array[float] = Layout.coordinates()
    for xi in range(axes.size()):
        for zi in range(axes.size()):
            var key := "%d:%d" % [xi, zi]
            var boundary_axes: int = int(xi == 0 or xi == axes.size() - 1) + int(
                zi == 0 or zi == axes.size() - 1)
            var form: String = "corner" if boundary_axes == 2 else (
                "t" if boundary_axes == 1 else "cross")
            result.append({"id": key,
                "position": Vector3(axes[xi], 0.0, axes[zi]),
                "junction_form": form,
                "junction_type": SIGNALIZED if key == MAIN_JUNCTION_ID else (
                    PRIORITY_T if key == "0:1" or key == "4:0" else LEGACY_OUTER)})
    result.append_array(NeighborhoodLink.nodes())
    return result

## Each edge is an undirected physical street with TWO directed lane IDs.
## Order is intentionally x -> z -> (x+1, z) then (x, z+1), matching
## CivicJunctionBuilder's pre-WORLD-001A stable lane allocation exactly.
static func roads() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var axes: Array[float] = Layout.coordinates()
    var lane_id: int = LEGACY_LANE_BASE
    for xi in range(axes.size()):
        for zi in range(axes.size()):
            var here := Vector3(axes[xi], 0.0, axes[zi])
            for neighbor in [Vector2i(xi + 1, zi), Vector2i(xi, zi + 1)]:
                if neighbor.x >= axes.size() or neighbor.y >= axes.size():
                    continue
                var there := Vector3(axes[neighbor.x], 0.0, axes[neighbor.y])
                var challenge: bool = Layout.is_challenge_segment(here, there)
                var organic_pilot: bool = Organic.is_pilot(here, there)
                var world_002_curve: bool = EastCurves.is_curve(here, there)
                result.append({"id": "road:%d" % lane_id,
                    "from_node": "%d:%d" % [xi, zi],
                    "to_node": "%d:%d" % [neighbor.x, neighbor.y],
                    "start": here, "end": there,
                    "centerline": Organic.centerline() if organic_pilot else (
                        EastCurves.centerline(here, there) if world_002_curve else
                        PackedVector3Array([here, there])),
                    "organic_pilot": organic_pilot,
                    "world_002_curve": world_002_curve,
                    "lane_forward": lane_id,
                    "lane_reverse": lane_id + 1,
                    "width_m": Layout.ROAD_WIDTH_M,
                    "speed_limit_mps": 5.5 if challenge else 8.0,
                    "road_type": MARKET if xi == 2 or zi == 2 else COLLECTOR,
                    "challenge": challenge,
                    "vehicle_access": true})
                lane_id += 2
    # Append only: retain all 40 old road IDs/ordering/geometry for saves.
    result.append_array(NeighborhoodLink.road_definitions())
    return result

static func bounds() -> Rect2:
    return Rect2(Vector2(-Layout.EXTENT_M, -Layout.EXTENT_M),
        Vector2.ONE * Layout.EXTENT_M * 2.0)

static func validate(nodes_data: Array[Dictionary], roads_data: Array[Dictionary]) -> PackedStringArray:
    var errors := PackedStringArray()
    var positions: Dictionary = {}
    for node in nodes_data:
        var key: String = str(node.get("id", ""))
        var location: Variant = node.get("position")
        if key.is_empty() or positions.has(key):
            errors.append("duplicate or missing node ID: " + key)
        elif not (location is Vector3) or not (location as Vector3).is_finite():
            errors.append("invalid position for node " + key)
        else:
            positions[key] = location
    var used: Dictionary = {}
    var road_keys: Dictionary = {}
    for road in roads_data:
        var key: String = str(road.get("id", ""))
        var source: String = str(road.get("from_node", ""))
        var target: String = str(road.get("to_node", ""))
        if key.is_empty() or road_keys.has(key):
            errors.append("duplicate or missing road ID: " + key)
        road_keys[key] = true
        if source == target or not positions.has(source) or not positions.has(target):
            errors.append("invalid road endpoints: " + key)
            continue
        var points: Variant = road.get("centerline")
        if not (points is PackedVector3Array) or (points as PackedVector3Array).size() < 2:
            errors.append("missing road centerline: " + key)
        else:
            var polyline: PackedVector3Array = points
            if polyline[0].distance_to(positions[source]) > 0.01 or (
                    polyline[polyline.size() - 1].distance_to(positions[target]) > 0.01):
                errors.append("centerline endpoints differ from road nodes: " + key)
            for point in polyline:
                if not point.is_finite():
                    errors.append("nonfinite road point: " + key)
        for id_key in ["lane_forward", "lane_reverse"]:
            var lane_id: int = int(road.get(id_key, -1))
            if lane_id < 0 or used.has(lane_id):
                errors.append("duplicate or negative lane ID on " + key)
            used[lane_id] = true
        if float(road.get("width_m", 0.0)) <= 0.0 or (
                float(road.get("speed_limit_mps", 0.0)) <= 0.0):
            errors.append("invalid physical dimensions: " + key)
    return errors
