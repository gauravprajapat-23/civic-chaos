extends SceneTree
## CAR-ART-04E: the player guard catches car contact even when the capsule
## is above the car's 1.2 m collider, without adding a car floor.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")

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
    ground.collision_mask = 0
    ground.position.y = -0.25
    var ground_shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(40, 0.5, 40)
    ground_shape.shape = floor_box
    ground.add_child(ground_shape)
    stage.add_child(ground)

    var car: CivicVehicleAgent = CarScene.instantiate() as CivicVehicleAgent
    car.feedback_enabled = false
    stage.add_child(car)
    var player: CivicPlayerController = PlayerScene.instantiate() as CivicPlayerController
    # Local position is valid before entering the scene tree. Assigning
    # global_position here calls get_global_transform() on an orphan node.
    player.position = Vector3(0, 1.35, 2.2)
    stage.add_child(player)
    await physics_frame
    # The ordinary capsule at this height is above the car collision box.
    # Only the extended query should recognize its horizontal projection.
    if player.collision_mask != 1:
        _fail("player acquired vehicle floor collisions")
        return
    var before: float = player.global_position.z
    Input.action_press("move_forward")
    for frame in range(8):
        await physics_frame
        if player.global_position.z < 1.65:
            _fail("airborne horizontal guard allowed entry into car silhouette")
            return
    Input.action_release("move_forward")
    if player._airborne_vehicle_guard == null:
        _fail("extended airborne vehicle query shape was never created")
        return
    if player.global_position.z >= before - 0.02:
        _fail("player could not approach the car at all")
        return

    # When the obstacle moves away, motion must immediately resume.
    car.global_position = Vector3(12, 0, 0)
    await physics_frame
    var released_from: float = player.global_position.z
    Input.action_press("move_forward")
    for frame in range(20):
        await physics_frame
    Input.action_release("move_forward")
    if player.global_position.z >= released_from - 0.25:
        _fail("vehicle guard remained active after the car moved")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_CAR_ART_04E_AIRBORNE_GUARD_PASS")
    quit(0)

func _fail(reason: String) -> void:
    Input.action_release("move_forward")
    push_error(reason)
    quit(1)
