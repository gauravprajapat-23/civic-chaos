extends SceneTree
## GAME-012: the E-key interaction ray must reach the non-solid marshal post.
const ReportPost = preload("res://scripts/civic/wrong_way_report_marker.gd")
const PlayerScene = preload("res://scenes/player/player_root.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var post := ReportPost.new() as CivicWrongWayReportMarker
    world.add_child(post)
    var player: CivicPlayerController = PlayerScene.instantiate() as CivicPlayerController
    world.add_child(player)
    # This isolated test checks only an interaction ray, not player movement.
    # The full main scene registers movement actions; the standalone fixture
    # intentionally does not, so keep its player physics process disabled.
    player.set_physics_process(false)
    player.global_position = Vector3(0, 0, -2.0)
    await physics_frame
    if post.collision_layer != 16 or post.collision_mask != 0:
        _fail("civic post must be targetable but never physically block the character")
        return
    if (CivicPlayerController.INTERACTION_COLLISION_MASK & 16) == 0:
        _fail("player E-key interaction ray excludes civic report posts")
        return
    if (CivicPlayerController.INTERACTION_COLLISION_MASK & 1) == 0:
        _fail("original world interactables no longer targetable")
        return
    var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.0, -2.0), Vector3(0, 1.0, 2.0))
    query.collision_mask = CivicPlayerController.INTERACTION_COLLISION_MASK
    query.exclude = [player.get_rid()]
    var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.get("collider") != post:
        _fail("civic report post was not detected by the actual physics raycast mask")
        return
    world.queue_free()
    print("CIVIC_CHAOS_WRONG_WAY_REPORT_POST_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
