extends SceneTree
## Prevent road/terrain coplanar rendering and player-on-pedestrian regression.
const MainScene = preload("res://scenes/core/main.tscn")
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const DistrictScene = preload("res://scenes/world/neighborhood.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var main := MainScene.instantiate()
    if main.get_node_or_null("Ground") != null:
        _fail("duplicate main scene ground")
        return
    main.free()
    var player := PlayerScene.instantiate() as CharacterBody3D
    if player.collision_mask != 1:
        _fail("player must stand on world surfaces, not pedestrians or cars")
        return
    player.free()
    var district := DistrictScene.instantiate()
    root.add_child(district)
    await process_frame
    var terrain := district.get_node("TerrainGround") as StaticBody3D
    var terrain_top: float = terrain.position.y + (terrain.get_node("CollisionShape3D").shape as BoxShape3D).size.y * 0.5
    for name in ["NorthRoad", "SouthRoad", "EastRoad", "WestRoad", "SecondaryRoad_NS_-1", "SecondaryRoad_EW_1"]:
        var road := district.get_node(name) as StaticBody3D
        var top: float = road.position.y + (road.get_node("CollisionShape3D").shape as BoxShape3D).size.y * 0.5
        if top < terrain_top + 0.02:
            _fail("road coplanar with terrain: " + name)
            return
        var mesh := road.get_node("MeshInstance3D") as MeshInstance3D
        if mesh.material_override == null or mesh.material_override.albedo_color.r > 0.25:
            _fail("road asphalt material missing: " + name)
            return
    district.queue_free()
    print("CIVIC_CHAOS_SURFACE_AND_PLAYER_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
