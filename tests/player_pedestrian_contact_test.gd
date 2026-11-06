extends SceneTree
## Player can walk freely past sensor-only NPCs; NPC heads are not floors.
const PlayerScene = preload("res://scenes/player/player_root.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # The main scene normally declares these actions in _enter_tree().
    for action in ["move_left", "move_right", "move_forward", "move_back", "look_left", "look_right", "look_up", "look_down", "sprint", "jump"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.collision_layer = 1
    ground.collision_mask = 0
    var floor_shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(40.0, 0.5, 40.0)
    floor_shape.shape = floor_box
    ground.position.y = -0.25
    ground.add_child(floor_shape)
    stage.add_child(ground)
    var pedestrian := AnimatableBody3D.new()
    pedestrian.name = "StationaryPedestrian"
    pedestrian.collision_layer = 8
    pedestrian.collision_mask = 1 | 2 | 8
    var npc_shape := CollisionShape3D.new()
    var npc_capsule := CapsuleShape3D.new()
    npc_capsule.radius = 0.32
    npc_capsule.height = 1.75
    npc_shape.shape = npc_capsule
    npc_shape.position.y = 0.87
    pedestrian.add_child(npc_shape)
    stage.add_child(pedestrian)
    var player := PlayerScene.instantiate() as CharacterBody3D
    if player == null:
        _fail("player scene is not CharacterBody3D")
        return
    player.position = Vector3(0.0, 0.1, 2.6)
    stage.add_child(player)
    await physics_frame
    if player.collision_mask != 1:
        _fail("player mask must use world for grounding, not actor roofs")
        return
    Input.action_press("move_forward")
    for frame in range(70):
        await physics_frame
    Input.action_release("move_forward")
    var delta := player.global_position - pedestrian.global_position
    delta.y = 0.0
    if player.global_position.z > -1.5:
        _fail("player was physically blocked by a sensing-only pedestrian")
        return
    if absf(player.global_position.x) > 0.5:
        _fail("pedestrian contact unexpectedly pushed player sideways")
        return
        return
    # Clear the walker and confirm that the obstacle guard releases.
    pedestrian.global_position = Vector3(10.0, 0.0, 0.0)
    await physics_frame
    var z_before: float = player.global_position.z
    Input.action_press("move_forward")
    for frame in range(45):
        await physics_frame
    Input.action_release("move_forward")
    if player.global_position.z >= z_before - 0.75:
        _fail("player movement stopped unexpectedly after pedestrian moved")
        return
    # The NPC capsule must not act as a solid floor while falling.
    pedestrian.global_position = Vector3.ZERO
    player.global_position = Vector3(0.0, 3.0, 0.0)
    player.velocity = Vector3.ZERO
    for frame in range(120):
        await physics_frame
    if player.global_position.y > 0.35 or player.global_position.y < -0.05 or absf(player.global_position.z) > 0.25 or not player.is_on_floor():
        _fail("player failed to land on world floor beneath pedestrian")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_PLAYER_PEDESTRIAN_CONTACT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    Input.action_release("move_forward")
    push_error(reason)
    quit(1)
