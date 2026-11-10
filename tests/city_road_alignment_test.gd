extends SceneTree
## AUD2-MAP-01: actual generated road shapes must cover every city lane.
## Test real scene collision geometry, not the grid constants alone.
const Builder = preload("res://scripts/world/junction_builder.gd")
const CityRoadLayout = preload("res://scripts/world/city_road_layout.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source: PackedScene = load("res://scenes/world/neighborhood.tscn") as PackedScene
    if source == null:
        _fail("district scene failed to load")
        return
    var district: Node3D = source.instantiate() as Node3D
    if district == null:
        _fail("district scene did not instantiate as Node3D")
        return
    root.add_child(district)
    await process_frame
    if not CityRoadLayout.valid_district_dimensions(
            float(district.get("district_extent")), float(district.get("road_width"))):
        _fail("playable district exported dimensions disagree with traffic grid")
        return

    var road_shapes: Array[Dictionary] = []
    for node in district.get_children():
        if not (node is StaticBody3D) or not str(node.name).contains("Road"):
            continue
        var body: StaticBody3D = node as StaticBody3D
        var collision: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        var mesh: MeshInstance3D = body.get_node_or_null("MeshInstance3D") as MeshInstance3D
        if collision == null or not (collision.shape is BoxShape3D):
            _fail("road is missing its real box collider: " + str(body.name))
            return
        if mesh == null or not (mesh.mesh is BoxMesh) or mesh.material_override == null or not mesh.visible:
            _fail("road collider has no visible paved mesh: " + str(body.name))
            return
        var bounds: Vector3 = (collision.shape as BoxShape3D).size
        if bounds.x <= 0.0 or bounds.z <= 0.0:
            _fail("road collider has an empty footprint: " + str(body.name))
            return
        road_shapes.append({"name": str(body.name), "center": collision.global_position,
            "half_size": bounds * 0.5})

    # Four central road halves + four secondary + four perimeter road strips.
    if road_shapes.size() != 12:
        _fail("expected twelve paved road bodies, got " + str(road_shapes.size()))
        return
    for side in [-1, 1]:
        for axis in ["NS", "EW"]:
            var name: String = "PerimeterRoad_%s_%d" % [axis, side]
            var road: StaticBody3D = district.get_node_or_null(name) as StaticBody3D
            if road == null or not road.visible:
                _fail("missing newly paved outer city road " + name)
                return

    var graph: CivicRoadGraph = Builder.make_city_graph()
    if graph.lane_count() != 80 or not graph.validate().is_empty():
        _fail("expanded-city lane graph not valid")
        return
    var sampled_points: int = 0
    for lane_id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(lane_id)
        if lane == null or lane.centerline.size() < 2:
            _fail("lane missing its renderable path " + str(lane_id))
            return
        for segment in range(1, lane.centerline.size()):
            for step in range(9):
                var t: float = float(step) / 8.0
                var point: Vector3 = lane.centerline[segment - 1].lerp(lane.centerline[segment], t)
                sampled_points += 1
                if not _covered_by_road(point, road_shapes):
                    _fail("unpainted lane %d at %s, segment %d, step %d" %
                        [lane_id, str(point), segment, step])
                    return
    if sampled_points != 2160:
        _fail("not all 80 four-point lane polylines were sampled")
        return
    if _covered_by_road(Vector3(20.0, 0.0, 20.0), road_shapes):
        _fail("negative case in an ordinary grass/building block was marked as paved")
        return
    district.queue_free()
    print("CIVIC_CHAOS_CITY_ROAD_ALIGNMENT_PASS")
    quit(0)

static func _covered_by_road(point: Vector3, roads: Array[Dictionary]) -> bool:
    for road in roads:
        var center: Vector3 = road["center"]
        var half: Vector3 = road["half_size"]
        if absf(point.x - center.x) <= half.x - 0.02 and absf(point.z - center.z) <= half.z - 0.02:
            return true
    return false

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
