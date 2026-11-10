extends SceneTree
## AUD2-MAP-01: neighborhood feature smoke plus newly paved perimeter.
## A failed condition must exit nonzero; do not rely on bare assert().
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var source: PackedScene = load("res://scenes/world/neighborhood.tscn") as PackedScene
    if source == null:
        _fail("neighborhood scene failed to load")
        return
    var district: Node3D = source.instantiate() as Node3D
    if district == null:
        _fail("neighborhood scene did not instantiate")
        return
    root.add_child(district)
    await process_frame
    if float(district.get("district_extent")) < 120.0:
        _fail("playable district became smaller than the city graph")
        return
    if not (district.get_node_or_null("TerrainGround") is StaticBody3D):
        _fail("terrain ground collider missing")
        return
    for boundary_name in ["BoundaryEW_-1", "BoundaryEW_1", "BoundaryNS_-1", "BoundaryNS_1"]:
        var wall: StaticBody3D = district.get_node_or_null(boundary_name) as StaticBody3D
        if wall == null:
            _fail("missing physical boundary " + boundary_name)
            return
        var collider: CollisionShape3D = wall.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if collider == null or collider.shape == null:
            _fail("boundary has no usable collider " + boundary_name)
            return
    for node_name in [
        "NorthRoad", "Building_1_1", "Crossing_0", "Crossing_3",
        "DistrictInfoPoint", "CommunityPark", "ParkFootpath", "OuterBuilding_0_0"
    ]:
        if district.get_node_or_null(node_name) == null:
            _fail("district feature missing: " + node_name)
            return
    if not (district.get_node_or_null("NorthRoad") is StaticBody3D):
        _fail("north road lost its physical body")
        return
    if not (district.get_node_or_null("ParkFootpath") is MeshInstance3D):
        _fail("park footpath lost its visible mesh")
        return
    for prefix in ["SecondaryRoad", "PerimeterRoad"]:
        for side in [-1, 1]:
            for axis in ["NS", "EW"]:
                var road_name: String = "%s_%s_%d" % [prefix, axis, side]
                var road: StaticBody3D = district.get_node_or_null(road_name) as StaticBody3D
                if road == null:
                    _fail("missing paved road " + road_name)
                    return
                var collider: CollisionShape3D = road.get_node_or_null("CollisionShape3D") as CollisionShape3D
                var visual: MeshInstance3D = road.get_node_or_null("MeshInstance3D") as MeshInstance3D
                if collider == null or collider.shape == null or visual == null or visual.mesh == null:
                    _fail("road is not physically and visually complete " + road_name)
                    return
    for name in ["NorthRoad", "SouthRoad", "EastRoad", "WestRoad", "TerrainGround", "Building_1_1"]:
        var body: StaticBody3D = district.get_node_or_null(name) as StaticBody3D
        if body == null:
            _fail("required static body missing " + name)
            return
        var shape: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if shape == null or shape.shape == null:
            _fail("required body collider missing " + name)
            return
    district.queue_free()
    print("CIVIC_CHAOS_NEIGHBORHOOD_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
