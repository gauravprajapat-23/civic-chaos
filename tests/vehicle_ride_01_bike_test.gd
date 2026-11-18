extends SceneTree
## VEHICLE-RIDE-01: real player owns the moving bike, keeping camera,
## keyboard/mobile actions and solid-world collision safe.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # The main gameplay scene registers these in Main._enter_tree().
    # This standalone SceneTree fixture never instantiates Main, so it
    # must register the same input actions before PlayerRoot enters tree.
    # Otherwise Godot emits repeated missing-action errors on every tick
    # even when the bike assertions eventually print PASS.
    for action in [
            "move_forward", "move_back", "move_left", "move_right",
            "look_left", "look_right", "look_up", "look_down",
            "jump", "sprint", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var world := Node3D.new()
    root.add_child(world)
    var ground := StaticBody3D.new()
    ground.name = "Ground"
    ground.collision_layer = 1
    ground.collision_mask = 0
    ground.position = Vector3(0, -0.3, 0)
    var ground_collider := CollisionShape3D.new()
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(80, 0.6, 80)
    ground_collider.shape = ground_box
    ground.add_child(ground_collider)
    world.add_child(ground)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(0, 0.15, 0)
    world.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    bike.name = "TestBike"
    bike.position = Vector3(1.2, 0.15, 0)
    world.add_child(bike)
    await physics_frame
    if bike.collision_layer != 16 or bike.get_node_or_null("FrontWheel") == null or bike.get_node_or_null("RearWheel") == null:
        _fail("parked bike missing usable interaction collider or low-poly wheels")
        return
    player.rotation.y = 0.7 # A restored character may face another direction.
    bike.rotation.y = 0.35
    var parked_heading: float = bike.global_rotation.y
    if not player.mount_bike(bike):
        _fail("nearby bike failed to mount")
        return
    if absf(angle_difference(player._bike_heading, parked_heading)) > 0.001 or (
            absf(angle_difference(bike.global_rotation.y, parked_heading)) > 0.001):
        _fail("mount snapped the bike away from its previous heading")
        return
    if player.ridden_bike != bike or bike.rider != player or bike.get_parent() != player or bike.collision_layer != 0:
        _fail("mounted bike has wrong rider, ownership or collider state")
        return
    if not is_equal_approx(player.spring_arm.spring_length, 5.7):
        _fail("bike camera did not provide a wider third-person view")
        return
    var before: Vector3 = player.global_position
    Input.action_press("move_forward")
    for frame in range(45):
        await physics_frame
    Input.action_release("move_forward")
    if player.global_position.distance_to(before) < 1.5:
        _fail("bike did not actually accelerate and carry the character")
        return
    if player._bike_speed < 0.1:
        _fail("bike speed was never applied from the movement input")
        return
    if player.dismount_bike():
        _fail("dismount accepted while bike was still moving")
        return
    var heading_before: float = player._bike_heading
    Input.action_press("move_forward")
    Input.action_press("move_right")
    for frame in range(15):
        await physics_frame
    Input.action_release("move_forward")
    Input.action_release("move_right")
    if absf(angle_difference(heading_before, player._bike_heading)) < 0.06:
        _fail("bike handlebar steering did not change physical heading")
        return
    Input.action_press("move_back")
    for frame in range(40):
        await physics_frame
    Input.action_release("move_back")
    if player._bike_speed > 0.2:
        _fail("bike brakes did not slow/stop it")
        return
    # Reverse now rolls rear and front wheels backwards, rather than
    # applying the same positive angular displacement in both directions.
    if player._bike_speed >= -0.2:
        _fail("bike never entered reverse from backward input")
        return
    if player.dismount_bike():
        _fail("reverse-motion dismount was not rejected")
        return
    Input.action_press("jump")
    for frame in range(25):
        await physics_frame
    Input.action_release("jump")
    if absf(player._bike_speed) > 0.25:
        _fail("dedicated brake did not stop reverse motion")
        return
    # Contact at the player's own location blocks dangerous dismount,
    # rather than placing the character through a stopped car.
    var obstacle := StaticBody3D.new()
    obstacle.collision_layer = 4
    obstacle.collision_mask = 0
    # Assign local coordinates before parenting. global_position on a
    # detached Node3D calls get_global_transform outside SceneTree.
    obstacle.position = player.global_position + Vector3.UP * 0.8
    var blocked_shape := CollisionShape3D.new()
    var collision := BoxShape3D.new()
    collision.size = Vector3(0.7, 1.4, 0.7)
    blocked_shape.shape = collision
    obstacle.add_child(blocked_shape)
    world.add_child(obstacle)
    await physics_frame
    if player.dismount_bike():
        _fail("bike allowed dismount into a real vehicle collider")
        return
    obstacle.queue_free()
    await physics_frame
    await physics_frame
    if not player.dismount_bike():
        _fail("safe stationary bike cannot be parked")
        return
    if player.ridden_bike != null or bike.get_parent() != world or bike.collision_layer != 16 or bike.rider != null:
        _fail("parking did not return bike to world and restore USE")
        return
    if player.collision_mask != 1 or not is_equal_approx(player.spring_arm.spring_length, 4.0):
        _fail("bike changed default player collision or permanently altered camera")
        return
    # Stop running player physics before removing the fixture and
    # quitting; avoid any last-frame callbacks touching freed children.
    player.set_physics_process(false)
    world.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_01_BIKE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    for action in ["move_forward", "move_back", "move_left", "move_right"]:
        Input.action_release(action)
    push_error(reason)
    quit(1)
