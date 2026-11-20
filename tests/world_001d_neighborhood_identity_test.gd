extends SceneTree
## WORLD-001D: visual variation must not change collision shape count,
## road network, mission anchors, or cause nondeterministic rebuild drift.
const Neighborhood = preload("res://scripts/world/neighborhood.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
var failures: int = 0

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-001D: " + reason)

func _count_physics(node: Node) -> int:
    var count: int = 1 if node is CollisionShape3D else 0
    for child in node.get_children():
        count += _count_physics(child)
    return count

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var before_graph: CivicRoadGraph = Builder.make_city_graph()
    var before_ids: Array[int] = before_graph.sorted_lane_ids()
    var district: CivicNeighborhood = Neighborhood.new() as CivicNeighborhood
    root.add_child(district)
    await process_frame
    var expected: Array[String] = ["MarketStreetIdentity", "OldBusStopIdentity",
        "ParkingCourtIdentity", "StreetIdentityLighting", "OrganicWestRoad"]
    for item in expected:
        _check(district.get_node_or_null(item) != null,
            "missing world landmark " + item)
    var park: Node3D = district.get_node_or_null("CommunityPark") as Node3D
    _check(park != null and park.has_node("ParkIdentity"),
        "park identity not attached to existing park")
    var shops: Node3D = district.get_node_or_null("OuterBuilding_0_0") as Node3D
    _check(shops != null and shops.has_node("LocalShopFront"),
        "market awning did not attach to an existing building")
    var markers: Node3D = district.get_node_or_null("OldBusStopIdentity") as Node3D
    if markers != null:
        _check(markers.position.distance_to(Vector3(-92, 0, 11)) < 0.01,
            "bus stop has drifted into a mission path")
        _check(_count_physics(markers) == 0,
            "bus stop visual unexpectedly obstructs walking/traffic")
    var parking: Node3D = district.get_node_or_null("ParkingCourtIdentity") as Node3D
    if parking != null:
        _check(_count_physics(parking) == 0,
            "parking decoration introduced a vehicle-blocking collider")
    var park_count: int = _count_physics(district)
    var road: Node3D = district.get_node_or_null("OrganicWestRoad") as Node3D
    _check(road != null and _count_physics(road) >= 1,
        "existing curved-road support collider disappeared")
    var marker: Node3D = district.get_node_or_null("DistrictInfoPoint") as Node3D
    _check(marker != null and marker.position.distance_to(
        Vector3(7, 0.2, -12)) < 0.01,
        "original interaction mission marker moved")
    district.rebuild()
    var after_count: int = _count_physics(district)
    _check(park_count == after_count,
        "rebuild changed physics collision count or duplicated actors")
    for item in expected:
        _check(district.get_node_or_null(item) != null,
            "rebuild removed visual landmark " + item)
    var after_graph: CivicRoadGraph = Builder.make_city_graph()
    _check(after_graph.sorted_lane_ids() == before_ids and
        after_graph.validate().is_empty(),
        "WORLD-001D decorations modified the traffic topology")
    district.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_001D_NEIGHBORHOOD_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_001D_NEIGHBORHOOD_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
