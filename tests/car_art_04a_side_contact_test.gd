extends SceneTree
## CAR-ART-04A: airborne horizontal movement toward a solid car cannot
## penetrate its cabin and remains free to move after the car is relocated.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_left", "move_right", "move_forward", "move_back",
            "look_left", "look_right", "look_up", "look_down", "sprint", "jump"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.collision_layer = 1
    ground.position.y = -0.25
    var ground_shape := CollisionShape3D.new()
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(40, 0.5, 40)
    ground_shape.shape = ground_box
    ground.add_child(ground_shape)
    stage.add_child(ground)
    var car: CivicVehicleAgent = VehicleScene.instantiate() as CivicVehicleAgent
    car.feedback_enabled = false
    stage.add_child(car)
    var player: CivicPlayerController = PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(0.0, 0.1, 3.45)
    stage.add_child(player)
    # Do not press jump against a player still falling into place. Godot
    # CharacterBody3D sets is_on_floor() only after move_and_slide(), and
    # eight ticks are not always enough to settle the initial 10 cm.
    var grounded: bool = false
    for frame in range(90):
        await physics_frame
        if player.is_on_floor():
            grounded = true
            break
    if not grounded:
        _fail("player did not settle on world ground before jump")
        return
    Input.action_release("jump")
    Input.action_press("move_forward")
    Input.action_press("jump")
    var started_airborne: bool = false
    for frame in range(4):
        await physics_frame
        if player.velocity.y > 0.25 and not player.is_on_floor():
            started_airborne = true
            break
    Input.action_release("jump")
    if not started_airborne:
        _fail("grounded jump did not generate an airborne impulse")
        return
    for frame in range(65):
        await physics_frame
        var relative: Vector3 = car.to_local(player.global_position)
        if absf(relative.x) < 1.0 and absf(relative.z) < 1.65 and player.global_position.y < 1.55:
            Input.action_release("move_forward")
            _fail("jumping player clipped into vehicle cabin")
            return
    Input.action_release("move_forward")
    var paused_z: float = player.global_position.z
    car.global_position = Vector3(12, 0, 0)
    await physics_frame
    Input.action_press("move_forward")
    for frame in range(40):
        await physics_frame
    Input.action_release("move_forward")
    if player.global_position.z >= paused_z - 0.7:
        _fail("player movement remained blocked after the car moved away")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_CAR_ART_04A_SIDE_CONTACT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    Input.action_release("move_forward")
    Input.action_release("jump")
    push_error(reason)
    quit(1)
