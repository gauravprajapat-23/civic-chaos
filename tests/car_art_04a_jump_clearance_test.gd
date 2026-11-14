extends SceneTree
## CAR-ART-04A: falling into the non-climbable cabin must never leave
## the player embedded in the car, while the vehicle stays non-floor.
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
    var floor_body := StaticBody3D.new()
    floor_body.collision_layer = 1
    floor_body.position.y = -0.25
    var floor_shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(40, 0.5, 40)
    floor_shape.shape = floor_box
    floor_body.add_child(floor_shape)
    stage.add_child(floor_body)

    var car: CivicVehicleAgent = VehicleScene.instantiate() as CivicVehicleAgent
    car.feedback_enabled = false
    stage.add_child(car)
    var player: CivicPlayerController = PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(0, 2.8, 0.0)
    stage.add_child(player)
    await physics_frame
    if player.collision_mask != 1:
        _fail("vehicle must not become an ordinary player floor")
        return

    # Drop directly through the roof's projected footprint. The recovery
    # should place the player beside a car, not inside the open cabin.
    for frame in range(110):
        await physics_frame
    var local: Vector3 = car.to_local(player.global_position)
    if absf(local.x) < 1.13 and absf(local.z) < 1.83:
        _fail("falling player remained inside the vehicle silhouette")
        return
    if not player.is_on_floor() or absf(player.global_position.y) > 0.25:
        _fail("player did not land on world ground after car clearance")
        return

    # A second fall close to the side must not push the player *into* the
    # body and must settle without floating on a fake vehicle roof.
    player.global_position = Vector3(1.0, 2.65, 0.1)
    player.velocity = Vector3.ZERO
    for frame in range(110):
        await physics_frame
    local = car.to_local(player.global_position)
    if absf(local.x) < 1.13 and absf(local.z) < 1.83:
        _fail("second airborne approach penetrated the vehicle cabin")
        return
    if not player.is_on_floor():
        _fail("airborne player never settled on actual ground")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_CAR_ART_04A_JUMP_CLEARANCE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
