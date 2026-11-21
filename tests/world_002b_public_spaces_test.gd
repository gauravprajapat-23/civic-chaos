extends SceneTree
## WORLD-002B: grounded public spaces are non-colliding and do not
## interfere with the 40-edge physical city, plots, or legacy scene nodes.
const World = preload("res://scripts/world/neighborhood.gd")
const Spaces = preload("res://scripts/world/world_002_public_spaces.gd")
const Buildings = preload("res://scripts/world/world_002_building_layout.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
const Organic = preload("res://scripts/world/organic_road_geometry.gd")
var failures: int = 0

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-002B: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(Buildings.valid_layout(), "WORLD-002A building layout invalid")
    _check(Spaces.valid_layout(), "public plazas overlap existing road/buildings")
    _check(Spaces.plots().size() == 3, "expected three public spaces")
    var seen: Dictionary = {}
    for plaza in Spaces.plots():
        var id: String = str(plaza["id"])
        _check(not seen.has(id), "duplicate plaza name")
        seen[id] = true
        var bounds: Rect2 = Spaces.bounds(plaza)
        _check(bounds.has_area(), "empty plaza footprint")
        for axis in Buildings.AXES:
            var center: Vector3 = plaza["center"]
            var size: Vector2 = plaza["size"]
            _check(absf(center.x - axis) - size.x * 0.5 >= Spaces.PLAZA_CLEARANCE_M,
                "plaza touches live X road axis")
            _check(absf(center.z - axis) - size.y * 0.5 >= Spaces.PLAZA_CLEARANCE_M,
                "plaza touches live Z road axis")
        for building in Buildings.all_buildings():
            var center: Vector3 = building["center"]
            var dims: Vector3 = building["size"]
            var footprint := Rect2(
                Vector2(center.x - dims.x * 0.5, center.z - dims.z * 0.5),
                Vector2(dims.x, dims.z))
            _check(not Spaces.overlaps(bounds, footprint, 1.0),
                "plaza overlaps building collision footprint")
    var roads := Network.roads()
    _check(roads.size() == 42, "network road inventory changed")
    var lane_ids: Dictionary = {}
    var organic_count: int = 0
    for road in roads:
        lane_ids[int(road["lane_forward"])] = true
        lane_ids[int(road["lane_reverse"])] = true
        if bool(road.get("organic_pilot", false)):
            organic_count += 1
            _check((road["centerline"] as PackedVector3Array) == Organic.centerline(),
                "organic west S-bend modified")
    _check(lane_ids.size() == 84 and organic_count == 1,
        "save-compatible lane IDs or organic road changed")
    var neighborhood: CivicNeighborhood = World.new() as CivicNeighborhood
    root.add_child(neighborhood)
    await process_frame
    var plazas: Node3D = neighborhood.get_node_or_null("World002PublicSpaces") as Node3D
    _check(plazas != null, "physical world did not build public spaces")
    if plazas != null:
        _check(plazas.get_child_count() == 3, "public-space count incorrect")
        for data in Spaces.plots():
            var square: Node3D = plazas.get_node_or_null("Square_" + str(data["id"])) as Node3D
            _check(square != null, "missing expected square " + str(data["id"]))
            if square == null:
                continue
            _check(square.position.distance_to(data["center"]) < 0.001,
                "square not at authored world position")
            _check(square.get_node_or_null("OpenPlazaSurface") is MeshInstance3D,
                "plaza surface missing")
            _check(square.get_node_or_null("SquareName") is Label3D,
                "local plaza identity label missing")
            for child in square.get_children():
                _check(child is MeshInstance3D or child is Label3D,
                    "unexpected node inside non-colliding public square")
                _check(not (child is PhysicsBody3D or child is CollisionShape3D),
                    "public square introduced a physical obstacle")
    _check(neighborhood.get_node_or_null("CommunityPark") != null,
        "old community park was replaced")
    _check(neighborhood.get_node_or_null("ParkingCourtIdentity") != null,
        "existing parking service was replaced")
    _check(neighborhood.get_node_or_null("OldBusStopIdentity") != null,
        "existing bus stop was replaced")
    _check(neighborhood.get_node_or_null("OrganicWestRoad") != null,
        "canonical physical curved street was removed")
    neighborhood.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_002B_PUBLIC_SPACES_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_002B_PUBLIC_SPACES_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
