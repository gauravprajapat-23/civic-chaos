extends SceneTree
## Regression: SceneTree roads often have auto-named CollisionShape3D
## children. These are safe flat supports, not blocked mount paths.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_forward", "move_back", "move_left", "move_right",
            "look_left", "look_right", "look_up", "look_down",
            "jump", "sprint", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var world := Node3D.new()
    root.add_child(world)
    var road := StaticBody3D.new()
    road.collision_layer = 1
    road.position.y = -0.3
    var floor_shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(80.0, 0.6, 80.0)
    floor_shape.shape = box
    road.add_child(floor_shape) # Intentionally unnamed
    world.add_child(road)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0.0)
    world.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    bike.position.y = 0.15
    world.add_child(bike)
    await physics_frame
    if Bike.single_collision_shape(road) != floor_shape:
        _fail("auto-named ground collision was not found")
        return
    if not player.mount_bike(bike):
        _fail("cannot mount over auto-named road support")
        return
    player.set_physics_process(false)
    player._bike_exit_cooldown = 0.0
    player._bike_speed = 0.0
    player.velocity = Vector3.ZERO
    player.global_position.y = 0.0
    await physics_frame
    if not player.dismount_bike():
        _fail("cannot park over auto-named ground")
        return
    player._bike_exit_cooldown = 0.0
    await physics_frame
    if not bike.footprint_clear_at(bike.global_position, bike.global_rotation.y, [player.get_rid()]):
        _fail("legitimate road support blocks parked bike footprint")
        return
    if not player._rider_place_clear(bike.global_position):
        _fail("legitimate ground support blocks rider standing capsule")
        return
    if not player._rider_transfer_clear(player.global_position, bike.global_position):
        _fail("legitimate road support blocks short mount transfer")
        return
    if not player.mount_bike(bike):
        _fail("bike cannot remount over unnamed road collision")
        return
    # Solid traffic obstacles must never inherit the ground exemption.
    var car := StaticBody3D.new()
    car.collision_layer = 4
    car.position = player.global_position + Vector3.UP * 0.85
    var car_shape := CollisionShape3D.new()
    var car_box := BoxShape3D.new()
    car_box.size = Vector3(1.0, 1.5, 1.0)
    car_shape.shape = car_box
    car.add_child(car_shape)
    world.add_child(car)
    await physics_frame
    if player._rider_place_clear(player.global_position):
        _fail("car collider was wrongly treated as traversable ground")
        return
    player.set_physics_process(false)
    world.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05D_UNNAMED_GROUND_REMOUNT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
