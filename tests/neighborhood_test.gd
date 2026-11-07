extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := load("res://scenes/world/neighborhood.tscn") as PackedScene
    assert(scene != null)
    var district := scene.instantiate() as Node3D
    root.add_child(district)
    await process_frame
    assert(district.district_extent >= 120.0)
    assert(district.get_node_or_null("TerrainGround") is StaticBody3D)
    for boundary_name in ["BoundaryEW_-1", "BoundaryEW_1", "BoundaryNS_-1", "BoundaryNS_1"]:
        var wall := district.get_node_or_null(boundary_name) as StaticBody3D
        assert(wall != null)
        assert(wall.get_node("CollisionShape3D").shape != null)
    assert(district.get_node_or_null("NorthRoad") is StaticBody3D)
    assert(district.get_node_or_null("Building_1_1") is StaticBody3D)
    assert(district.get_node_or_null("Crossing_0") != null)
    assert(district.get_node_or_null("Crossing_3") != null)
    assert(district.get_node_or_null("DistrictInfoPoint") != null)
    assert(district.get_node_or_null("CommunityPark") is StaticBody3D)
    assert(district.get_node_or_null("ParkFootpath") is MeshInstance3D)
    for road_name in ["SecondaryRoad_NS_-1", "SecondaryRoad_NS_1", "SecondaryRoad_EW_-1", "SecondaryRoad_EW_1"]:
        var road := district.get_node_or_null(road_name) as StaticBody3D
        assert(road != null)
        assert(road.get_node("CollisionShape3D").shape != null)
    assert(district.get_node_or_null("OuterBuilding_0_0") is StaticBody3D)
    for name in ["NorthRoad", "SouthRoad", "EastRoad", "WestRoad", "TerrainGround", "Building_1_1"]:
        var body := district.get_node(name) as StaticBody3D
        assert(body.get_node("CollisionShape3D").shape != null)
    district.queue_free()
    print("CIVIC_CHAOS_NEIGHBORHOOD_PASS")
    quit(0)
