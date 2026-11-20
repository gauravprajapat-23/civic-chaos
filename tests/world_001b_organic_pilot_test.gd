extends SceneTree
## WORLD-001B: actual curved roadway, matching directed lane geometry and
## zero changes to the central mission intersection / historical lane IDs.
const Organic = preload("res://scripts/world/organic_road_geometry.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Neighborhood = preload("res://scripts/world/neighborhood.gd")

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _assert(value: bool, reason: String) -> void:
    if not value:
        failures += 1
        push_error("WORLD-001B: " + reason)

func _run() -> void:
    var points: PackedVector3Array = Organic.centerline()
    _assert(points.size() >= 20, "road curve is undersampled")
    _assert(points[0] == Organic.PILOT_FROM and points[points.size() - 1] == Organic.PILOT_TO,
        "curve moved original junction endpoints")
    _assert(points[int(points.size() / 2)].x > Organic.PILOT_FROM.x + 1.5,
        "pilot is still a straight road")
    for p in points:
        _assert(p.x >= -120.05 and p.x <= -116.0 and p.z >= -120.05 and p.z <= -45.95,
            "road curve leaves safe western district block")
    var roads: Array[Dictionary] = Network.roads()
    var pilot: Dictionary = {}
    var count: int = 0
    for edge in roads:
        if bool(edge.get("organic_pilot", false)):
            count += 1
            pilot = edge
    _assert(count == 1, "expected exactly one pilot road")
    _assert(int(pilot.get("lane_forward", -1)) == 102 and
        int(pilot.get("lane_reverse", -1)) == 103,
        "changed saved traffic lane identities")
    _assert(pilot.get("centerline") == points, "network and mesh centerline diverged")
    var west_t: Dictionary = {}
    for node in Network.nodes():
        if node["id"] == "0:1":
            west_t = node
            break
    _assert(west_t.get("junction_form", "") == "t" and (
        west_t.get("junction_type", "") == Network.LEGACY_OUTER),
        "curve endpoint T-junction was moved or silently recontrolled")
    var graph: CivicRoadGraph = Builder.make_city_graph()
    _assert(graph.lane_count() == 80 and graph.validate().is_empty(),
        "pilot invalidated old road graph")
    for lane_id in [102, 103]:
        var lane: CivicLaneData = graph.get_lane(lane_id)
        _assert(lane != null, "pilot directed lane missing")
        if lane == null:
            continue
        _assert(lane.centerline.size() == points.size(),
            "pilot traffic no longer samples pavement curve")
        _assert(lane.next_lane_ids.size() >= 1,
            "pilot roadway disconnected from remaining city")
        for i in range(1, lane.centerline.size() - 1):
            var position: Vector3 = lane.centerline[i]
            var near: float = INF
            for asphalt in points:
                near = minf(near, position.distance_to(asphalt))
            _assert(near < 2.0,
                "vehicle waypoint outside road surface")
    var central: CivicLaneData = graph.get_lane(122)
    _assert(central != null, "legacy central/outer lane removed")
    var mesh: ArrayMesh = Organic.surface_mesh(points)
    _assert(mesh.get_surface_count() == 1,
        "pilot has no actual asphalt triangles")
    if mesh.get_surface_count() == 1:
        var arrays: Array = mesh.surface_get_arrays(0)
        _assert((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == points.size() * 2,
            "asphalt mesh did not follow sampled centerline")
        _assert((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() ==
            (points.size() - 1) * 6,
            "asphalt faces missing")
    var district: CivicNeighborhood = Neighborhood.new() as CivicNeighborhood
    root.add_child(district)
    await process_frame
    var road: StaticBody3D = district.get_node_or_null("OrganicWestRoad") as StaticBody3D
    _assert(road != null, "new collidable road missing from playable world")
    if road != null:
        var collider: CollisionShape3D = road.get_node_or_null("CollisionShape3D")
        _assert(collider != null and collider.shape != null,
            "asphalt road has no collision geometry")
    _assert(district.get_node_or_null("OrganicWestTJunctionMarker") != null,
        "live T-junction sign not present")
    var old_full: StaticBody3D = district.get_node_or_null("PerimeterRoad_NS_-1") as StaticBody3D
    _assert(old_full != null, "legacy road continuation missing")
    if old_full != null:
        var old_mesh: MeshInstance3D = old_full.get_node_or_null("MeshInstance3D")
        if old_mesh != null and old_mesh.mesh is BoxMesh:
            _assert((old_mesh.mesh as BoxMesh).size.z < 200,
                "old straight road still fills the curved pilot segment")
    district.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_001B_ORGANIC_PILOT_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_001B_ORGANIC_PILOT_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
