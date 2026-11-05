extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := load("res://scenes/world/neighborhood.tscn") as PackedScene
    assert(scene != null)
    var district := scene.instantiate() as Node3D
    root.add_child(district)
    await process_frame
    assert(district.get_node_or_null("NorthRoad") is StaticBody3D)
    assert(district.get_node_or_null("Building_1_1") is StaticBody3D)
    assert(district.get_node_or_null("Crossing_0") != null)
    assert(district.get_node_or_null("Crossing_3") != null)
    assert(district.get_node_or_null("DistrictInfoPoint") != null)
    for name in ["NorthRoad", "SouthRoad", "EastRoad", "WestRoad", "Building_1_1"]:
        var body := district.get_node(name) as StaticBody3D
        assert(body.get_node("CollisionShape3D").shape != null)
    district.queue_free()
    print("CIVIC_CHAOS_NEIGHBORHOOD_PASS")
    quit(0)
