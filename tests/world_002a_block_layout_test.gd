extends SceneTree
## WORLD-002A: preserve active roads, route identifiers, old scene node
## contracts and park while physically varying static building footprints.
const World = preload("res://scripts/world/neighborhood.gd")
const Layout = preload("res://scripts/world/world_002_building_layout.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
const Organic = preload("res://scripts/world/organic_road_geometry.gd")
var failures: int = 0

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-002A: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(Layout.valid_layout(), "staggered block layout overlaps a road")
    var records: Array[Dictionary] = Layout.all_buildings()
    _check(records.size() == 15, "physical building inventory changed")
    var old_centers: int = 0
    var shapes: Dictionary = {}
    var style_names: Dictionary = {}
    for item in records:
        _check(Layout.clear_of_roads(item), "building footprint touches live road")
        var center: Vector3 = item["center"]
        var row: int = item["row"]
        var column: int = item["column"]
        if is_equal_approx(center.x, Layout.BASES[column]) and (
                is_equal_approx(center.z, Layout.BASES[row])):
            old_centers += 1
        var shape: Vector3 = item["size"]
        shapes["%.1f:%.1f:%.1f" % [shape.x, shape.y, shape.z]] = true
        style_names[str(item["style"])] = true
    _check(old_centers < 4, "outer city still follows old uniform centers")
    _check(shapes.size() >= 7 and style_names.size() == 4,
        "world still has repetitive sizes and frontage styles")
    _check(Layout.building(1, 2, 8.0).is_empty(),
        "existing community park plot was overwritten")

    var roads: Array[Dictionary] = Network.roads()
    _check(roads.size() == 42, "road count or topology changed")
    var ids: Dictionary = {}
    var pilot_count: int = 0
    for road in roads:
        ids[int(road["lane_forward"])] = true
        ids[int(road["lane_reverse"])] = true
        if bool(road.get("organic_pilot", false)):
            _check((road["centerline"] as PackedVector3Array) == Organic.centerline(),
                "organic drivable street lost its sampled geometry")
            pilot_count += 1
    _check(ids.size() == 84 and pilot_count == 1,
        "traffic IDs or organic road inventory changed")

    var neighborhood := World.new() as CivicNeighborhood
    root.add_child(neighborhood)
    await process_frame
    _check(neighborhood.get_node_or_null("CommunityPark") != null,
        "community park lost original node identity")
    _check(neighborhood.get_node_or_null("OrganicWestRoad") != null,
        "real curved asphalt missing")
    var actual_variants: Dictionary = {}
    for item in records:
        var house := neighborhood.get_node_or_null(str(item["name"])) as StaticBody3D
        if house == null:
            _check(false, "missing physical building: " + str(item["name"]))
            continue
        var center: Vector3 = item["center"]
        _check(house.position.distance_to(center) < 0.001,
            "physical building not placed at authored position")
        var collision := house.get_node_or_null("CollisionShape3D") as CollisionShape3D
        _check(collision != null and collision.shape is BoxShape3D,
            "physical building collision shape missing")
        if collision != null and collision.shape is BoxShape3D:
            var cube := collision.shape as BoxShape3D
            _check(cube.size.distance_to(item["size"]) < 0.001,
                "building visual and physical shell do not share dimensions")
        var facade := house.get_node_or_null("World002Facade") as Node3D
        _check(facade != null, "distinctive building facade missing")
        if facade != null:
            actual_variants[str(item["style"])] = true
            for child in facade.get_children():
                _check(child is MeshInstance3D and not (child is CollisionObject3D),
                    "facade added unintended physics collider")
    _check(actual_variants.size() == 4,
        "neighborhood building facades not represented")
    neighborhood.queue_free()

    if failures == 0:
        print("CIVIC_CHAOS_WORLD_002A_BLOCK_LAYOUT_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_002A_BLOCK_LAYOUT_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
