extends SceneTree
## 05A: Bike cannot teleport into a car at mount or overlap a
## neighboring full-size NPC car. The actual source bike stays parked.
const Bike = preload("res://scripts/world/rideable_bike.gd")
const PlayerScene = preload("res://scenes/player/player_root.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_left", "move_right", "move_forward", "move_back",
            "look_left", "look_right", "look_up", "look_down",
            "sprint", "jump", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.collision_layer = 1
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(40, 0.4, 40)
    var ground_shape := CollisionShape3D.new()
    ground_shape.name = "CollisionShape3D"
    ground_shape.shape = ground_box
    ground.position = Vector3(0, -0.2, 0)
    ground.add_child(ground_shape)
    stage.add_child(ground)

    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.8, 0, 0)
    stage.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    bike.position = Vector3.ZERO
    stage.add_child(bike)
    var car := StaticBody3D.new()
    car.name = "ParkedCollisionCar"
    car.collision_layer = 4
    var car_shape := CollisionShape3D.new()
    car_shape.name = "CollisionShape3D"
    var car_box := BoxShape3D.new()
    car_box.size = Vector3(1.6, 1.2, 3.0)
    car_shape.shape = car_box
    car_shape.position.y = 0.7
    car.add_child(car_shape)
    car.position = Vector3(0.72, 0, 0)
    stage.add_child(car)
    await physics_frame

    if bike.footprint_clear_at(bike.global_position, 0.0, [player.get_rid()]):
        _fail("bike ignored a car overlapping its right side")
        return
    var bike_parked_position := bike.global_position
    var player_original_position := player.global_position
    if player.mount_bike(bike):
        _fail("bike mounted through a parked car")
        return
    if not bike_parked_position.is_equal_approx(bike.global_position) or (
            not player_original_position.is_equal_approx(player.global_position)):
        _fail("failed mount moved rider or bike")
        return

    car.position = Vector3(4, 0, 0)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("clear bike should mount after obstruction leaves")
        return
    if player.global_position.distance_to(bike_parked_position) > 0.01:
        _fail("bike teleported to the player instead of placing rider at parked bike")
        return
    if bike.get_parent() != player:
        _fail("mounted bike did not belong to rider")
        return
    var sensed := bike.get_node_or_null("MountedBikeTrafficSensor") as StaticBody3D
    if sensed == null or sensed.collision_layer != 2 or sensed.collision_mask != 0:
        _fail("NPCs cannot sense complete mounted motorcycle footprint")
        return
    if not is_equal_approx((sensed.get_node("CollisionShape3D").shape as BoxShape3D).size.z,
            Bike.FOOTPRINT_SIZE.z):
        _fail("NPC awareness proxy does not use full bike geometry")
        return
    player.set_physics_process(false)
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05A_MOUNT_CAR_CLEARANCE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
