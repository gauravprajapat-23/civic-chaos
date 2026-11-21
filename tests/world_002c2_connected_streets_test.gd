extends SceneTree
## WORLD-002C2: connected northeast loop, T at old corner, new IDs
## after legacy 100..179; actual asphalt and drivable lane graph parity.
const Network = preload("res://scripts/world/city_network_definition.gd")
const Connector = preload("res://scripts/world/world_002_neighborhood_connector.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const World = preload("res://scripts/world/neighborhood.gd")
const Squares = preload("res://scripts/world/world_002_public_spaces.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
var failures: int = 0

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-002C2: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(Connector.valid_clearances(), "connector intersects existing building or plaza")
    var nodes: Array[Dictionary] = Network.nodes()
    var roads: Array[Dictionary] = Network.roads()
    _check(nodes.size() == 26 and roads.size() == 42,
        "node/road count does not reflect additive network expansion")
    _check(Network.validate(nodes, roads).is_empty(),
        "new T-junction roads fail canonical network validation")
    var lane_ids: Dictionary = {}
    var history: Array[int] = []
    for road in roads:
        var forward: int = int(road["lane_forward"])
        var reverse: int = int(road["lane_reverse"])
        lane_ids[forward] = true
        lane_ids[reverse] = true
        if forward < 1000:
            history.append(forward)
            history.append(reverse)
    history.sort()
    _check(history.size() == 80 and history[0] == 100 and history[79] == 179,
        "old lane IDs changed")
    _check(lane_ids.size() == 84 and lane_ids.has(1000) and lane_ids.has(1001)
        and lane_ids.has(1002) and lane_ids.has(1003),
        "new lane IDs absent or duplicate")
    _check(str(nodes[nodes.size() - 1]["id"]) == Connector.CONNECTOR_ID,
        "missing neighborhood junction")
    _check(str(nodes[24]["id"]) == "4:4",
        "legacy node ordering changed")
    var existing_corner: Dictionary = {}
    for node in nodes:
        if str(node["id"]) == "4:0":
            existing_corner = node
    _check(str(existing_corner.get("junction_type", "")) == Network.PRIORITY_T,
        "the old corner was not marked as a new unsignalized T")
    for new_road in Connector.road_definitions():
        var from: Vector3 = new_road["start"]
        var to: Vector3 = new_road["end"]
        _check(new_road["centerline"] == Connector.centerline(from, to),
            "canonical map uses different road geometry")
        _check(Connector.asphalt_mesh(from, to).get_surface_count() > 0,
            "physical road has no asphalt surface")
    var graph: CivicRoadGraph = Builder.make_city_graph()
    _check(graph.validate().is_empty() and graph.lane_count() == 84,
        "expanded network has disconnected/malformed driving routes")
    for lane_id in [1000, 1002]:
        var lane: CivicLaneData = graph.get_lane(lane_id)
        var back: CivicLaneData = graph.get_lane(lane_id + 1)
        _check(lane != null and back != null,
            "missing opposing direction for neighborhood connector")
        if lane == null or back == null:
            continue
        _check(not lane.next_lane_ids.is_empty() and not back.next_lane_ids.is_empty(),
            "new streets do not connect to rest of traffic")
        _check(lane.speed_limit_mps <= 4.0 and back.speed_limit_mps <= 4.0,
            "neighborhood road speed exceeds low-speed policy")
    _check(graph.get_lane(1000).next_lane_ids.has(1002),
        "west-to-east neighborhood bypass cannot complete at new node")
    _check(graph.get_lane(1003).next_lane_ids.has(1001),
        "east-to-west neighborhood bypass cannot complete at new node")
    var legacy: CivicLaneData = graph.get_lane(102)
    _check(legacy != null and not legacy.next_lane_ids.is_empty(),
        "legacy save route disconnected by new T")
    var spawner: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    _check(spawner.configure(graph, 4701, true),
        "expanded city graph rejected by legacy traffic spawner")
    root.add_child(spawner)
    await physics_frame
    _check(graph.has_lane(102) and graph.has_lane(179),
        "old traffic checkpoint route lane IDs are unavailable")
    spawner.queue_free()

    var neighborhood: CivicNeighborhood = World.new() as CivicNeighborhood
    root.add_child(neighborhood)
    await process_frame
    _check(neighborhood.get_node_or_null("World002NeighborhoodJunction") != null,
        "new junction not present in physical world")
    for lane_id in [1000, 1002]:
        var body := neighborhood.get_node_or_null(
            "World002ConnectedRoad_%d" % lane_id) as StaticBody3D
        _check(body != null, "physical asphalt body missing")
        if body == null:
            continue
        var mesh := body.get_node_or_null("Asphalt") as MeshInstance3D
        var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        _check(mesh != null and mesh.mesh is ArrayMesh,
            "new connector missing visual asphalt")
        _check(shape != null and shape.shape != null,
            "new connector missing collision support")
    _check(neighborhood.get_node_or_null("World002PublicSpaces") != null
        and Squares.valid_layout(), "existing squares lost after new connector")
    _check(neighborhood.get_node_or_null("OrganicWestRoad") != null,
        "existing west curved road removed")
    neighborhood.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_002C2_CONNECTED_STREETS_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_002C2_CONNECTED_STREETS_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
