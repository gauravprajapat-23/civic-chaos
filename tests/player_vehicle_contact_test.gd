extends SceneTree
## Physics-frame player/parked-car contact, clearance release and no-roof test.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_left", "move_right", "move_forward", "move_back", "look_left", "look_right", "look_up", "look_down", "sprint", "jump"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.collision_layer = 1
    ground.collision_mask = 0
    var ground_shape := CollisionShape3D.new()
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(40, 0.5, 40)
    ground_shape.shape = ground_box
    ground.position.y = -0.25
    ground.add_child(ground_shape)
    stage.add_child(ground)

    var car := VehicleScene.instantiate() as CivicVehicleAgent
    stage.add_child(car)
    var body := car.get_node("CollisionBody") as StaticBody3D
    if body.collision_layer != 4:
        _fail("car collider must be on vehicle layer 4")
        return
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(0.0, 0.1, 3.6)
    stage.add_child(player)
    await physics_frame
    if player.collision_mask != 1:
        _fail("player mask must only collide with world surfaces")
        return

    Input.action_press("move_forward")
    for frame in range(85):
        await physics_frame
    Input.action_release("move_forward")
    var approach_z: float = player.global_position.z
    if approach_z < 1.75:
        _fail("player passed through parked car instead of stopping")
        return
    if approach_z >= 3.2:
        _fail("player did not approach parked car; obstacle test is vacuous")
        return
    if not player.is_on_floor():
        _fail("player lost world grounding while stopping for car")
        return

    car.global_position = Vector3(12, 0, 0)
    await physics_frame
    Input.action_press("move_forward")
    for frame in range(50):
        await physics_frame
    Input.action_release("move_forward")
    if player.global_position.z >= approach_z - 1.0:
        _fail("player did not resume after parked car moved")
        return

    car.global_position = Vector3.ZERO
    player.global_position = Vector3(0.0, 3.0, 0.0)
    player.velocity = Vector3.ZERO
    for frame in range(120):
        await physics_frame
    if player.global_position.y > 0.35 or player.global_position.y < -0.05 or not player.is_on_floor():
        _fail("car roof became a floor or player missed the ground")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_PLAYER_VEHICLE_CONTACT_PASS")
    quit(0)

func _fail(message: String) -> void:
    Input.action_release("move_forward")
    push_error(message)
    quit(1)
