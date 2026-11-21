extends SceneTree
## WORLD-002C: two new curved physical street sections must match the
## canonical network, on-map polylines and traffic lanes exactly.
const Network = preload("res://scripts/world/city_network_definition.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const East = preload("res://scripts/world/world_002_road_curves.gd")
const World = preload("res://scripts/world/neighborhood.gd")
const West = preload("res://scripts/world/organic_road_geometry.gd")
var failures: int = 0

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-002C: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(East.valid_geometry(), "sampled east geometry invalid")
    _check(Network.SCHEMA_VERSION == 1, "legacy save schema changed")
    var roads: Array[Dictionary] = Network.roads()
    _check(roads.size() == 40, "legacy 40-edge street topology changed")
    _check(Network.validate(Network.nodes(), roads).is_empty(),
        "canonical network now has malformed edges")
    var ids: Dictionary = {}
    var curves: Dictionary = {}
    var original_west: int = 0
    for road in roads:
        ids[int(road["lane_forward"])] = true
        ids[int(road["lane_reverse"])] = true
        if bool(road.get("organic_pilot", false)):
            original_west += 1
            _check((road["centerline"] as PackedVector3Array) == West.centerline(),
                "west curved pilot changed")
        if bool(road.get("world_002_curve", false)):
            var first: Vector3 = road["start"]
            var last: Vector3 = road["end"]
            var points: PackedVector3Array = road["centerline"]
            _check(points == East.centerline(first, last),
                "map/traffic network does not use road surface centerline")
            _check(points.size() == 25 and points[0] == first and
                points[points.size() - 1] == last,
                "curved road changed its original junction endpoints")
            _check(points[12].x < first.x - 2.0,
                "curve became visually indistinguishable from legacy grid")
            curves[int(road["lane_forward"])] = road
    _check(ids.size() == 80 and curves.size() == 2 and original_west == 1,
        "lane IDs or number of organic edges changed")
    _check(curves.has(172) and curves.has(178),
        "old checkpoint lane IDs not maintained for east curves")

    var graph: CivicRoadGraph = Builder.make_city_graph()
    _check(graph.validate().is_empty() and graph.lane_count() == 80,
        "new roads broke graph legal routing or save lane count")
    for lane_id in [172, 178]:
        if not curves.has(lane_id):
            continue
        var edge: Dictionary = curves[lane_id]
        var forward: CivicLaneData = graph.get_lane(lane_id)
        var reverse: CivicLaneData = graph.get_lane(lane_id + 1)
        _check(forward != null and reverse != null,
            "missing drivable lane for canonical curve")
        if forward == null or reverse == null:
            continue
        var points: PackedVector3Array = edge["centerline"]
        _check(forward.centerline == East.driving_lane(edge["start"], edge["end"]),
            "forward lane not sourced from curved-road geometry")
        _check(reverse.centerline == East.driving_lane(edge["end"], edge["start"]),
            "reverse lane not sourced from curved-road geometry")
        _check(forward.centerline[0] == edge["start"] and
            forward.centerline[forward.centerline.size() - 1] == edge["end"],
            "forward lane junction endpoints changed")
        _check(reverse.centerline[0] == edge["end"] and
            reverse.centerline[reverse.centerline.size() - 1] == edge["start"],
            "reverse lane junction endpoints changed")
        var midpoint: int = 12
        var back: int = reverse.centerline.size() - 1 - midpoint
        _check(forward.centerline[midpoint].distance_to(reverse.centerline[back]) >= 2.35,
            "opposing driving lanes overlap at curve apex")
        _check(forward.length_m() >= 74.0 and reverse.length_m() >= 74.0,
            "saved traffic distance range was shortened")
        _check(not forward.next_lane_ids.is_empty() and
            not reverse.next_lane_ids.is_empty(), "curved road disconnected at junction")
        var asphalt: ArrayMesh = East.asphalt_mesh(edge["start"], edge["end"])
        _check(asphalt.get_surface_count() > 0,
            "physical road ribbon lacks triangles")
        _check(points[0].distance_to(points[points.size() - 1]) >= 74.0,
            "physical connection no longer spans original nodes")

    var neighborhood := World.new() as CivicNeighborhood
    root.add_child(neighborhood)
    await process_frame
    _check(neighborhood.get_node_or_null("PerimeterRoad_NS_1") is StaticBody3D,
        "historic east-road scene node was removed")
    _check(neighborhood.get_node_or_null("PerimeterRoad_EastNorthCap") is StaticBody3D and
        neighborhood.get_node_or_null("PerimeterRoad_EastSouthCap") is StaticBody3D,
        "east perimeter endpoint caps are missing")
    var central := neighborhood.get_node_or_null("PerimeterRoad_NS_1") as StaticBody3D
    if central != null:
        var shape := central.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if shape != null and shape.shape is BoxShape3D:
            var size: Vector3 = (shape.shape as BoxShape3D).size
            _check(size.z < 100.0, "old full-length straight collider still overlaps curves")
        else:
            _check(false, "central east asphalt collision shape missing")
    for suffix in ["North", "South"]:
        var body := neighborhood.get_node_or_null("World002EastRoad_" + suffix) as StaticBody3D
        _check(body != null, "new physical curved road missing: " + suffix)
        if body != null:
            var surface := body.get_node_or_null("Asphalt") as MeshInstance3D
            var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
            _check(surface != null and surface.mesh is ArrayMesh,
                "curved road visible mesh missing")
            _check(collision != null and collision.shape != null,
                "curved road physically lacks supporting collider")
    _check(neighborhood.get_node_or_null("OrganicWestRoad") != null,
        "west curve removed by east expansion")
    _check(neighborhood.get_node_or_null("World002PublicSpaces") != null,
        "public squares lost after roads changed")
    neighborhood.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_002C_ORGANIC_ROADS_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_002C_ORGANIC_ROADS_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
