extends SceneTree
## AUD3-ART-01: recognizable characters, unchanged physics and animation nodes.
const CharacterArt = preload("res://scripts/rendering/low_poly_character.gd")
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Owner = preload("res://scripts/civic/parking_owner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var player: CivicPlayerController = PlayerScene.instantiate() as CivicPlayerController
    if player == null:
        _fail("player scene failed to instantiate")
        return
    var body: CollisionShape3D = player.get_node("CollisionShape3D") as CollisionShape3D
    if body == null or not (body.shape is CapsuleShape3D):
        _fail("existing player physics capsule missing")
        return
    if player.collision_layer != 2 or player.collision_mask != 1:
        _fail("player collision policy changed during art upgrade")
        return
    # A standalone SceneTree test does not instantiate Main, which normally
    # registers input actions. Disable player simulation AFTER entering tree;
    # pre-tree set_physics_process(false) is not sufficient for this fixture.
    root.add_child(player)
    player.set_physics_process(false)
    player.set_process_unhandled_input(false)
    await process_frame
    var visual := player.get_node("Visual") as Node3D
    if visual == null or visual.get_node_or_null("Head/Face") == null or visual.get_node_or_null("Head/HairCap") == null:
        _fail("player face/hair details missing")
        return
    for name in ["LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
        if not (visual.get_node_or_null(name) is Node3D):
            _fail("legacy player animation pivot missing: " + name)
            return
        var pivot: Node3D = visual.get_node(name)
        if pivot.get_child_count() < 2:
            _fail("low-poly limb missing shaped clothing/hand or shoe: " + name)
            return
    if visual.get_node_or_null("Torso/Shirt") == null or visual.get_node_or_null("LeftLeg/Shoe") == null:
        _fail("shirt or footwear not present")
        return

    var owner := Owner.new() as CivicParkingOwner
    root.add_child(owner)
    await process_frame
    if owner.collision_layer != 16 or owner.get_node_or_null("Head/Face") == null or owner.get_node_or_null("Torso/Shirt") == null:
        _fail("parking owner appearance or interaction-only layer changed")
        return
    var npc := Node3D.new()
    root.add_child(npc)
    var limbs: Dictionary = CharacterArt.build(npc, Color(0.3, 0.5, 0.7),
        Color(0.7, 0.5, 0.3), Color(0.2, 0.2, 0.3), Color(1, 0.8, 0.2))
    if limbs.size() != 4 or npc.get_node_or_null("Head/EyeL") == null:
        _fail("shared pedestrian art is not complete")
        return
    if npc.get_node_or_null("Torso") is CollisionObject3D:
        _fail("decorative meshes unexpectedly received collision")
        return
    npc.queue_free()
    owner.queue_free()
    player.queue_free()
    print("CIVIC_CHAOS_AUD3_CHARACTER_VISUAL_UPGRADE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
