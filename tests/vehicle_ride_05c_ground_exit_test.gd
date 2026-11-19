extends SceneTree
## VEHICLE-RIDE-05C: parked bike exit on a solid road after physics
## settle must not treat the road itself as a blocking wall.
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
    var ground := StaticBody3D.new()
    ground.collision_layer = 1
    ground.position.y = -0.3
    var floor_cs := CollisionShape3D.new()
    floor_cs.name = "CollisionShape3D"
    var floor_shape := BoxShape3D.new()
    floor_shape.size = Vector3(80, 0.6, 80)
    floor_cs.shape = floor_shape
    ground.add_child(floor_cs)
    world.add_child(ground)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0)
    world.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    world.add_child(bike)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("unobstructed motorcycle cannot mount over floor")
        return
    player.set_physics_process(false)
    player._bike_exit_cooldown = 0.0
    player._bike_speed = 0.0
    player.velocity = Vector3.ZERO
    # Small physics settling offsets must never make a supported side
    # exit appear occupied by the road surface itself.
    player.global_position.y = -0.05
    await physics_frame
    if not player._rider_place_clear(player.global_position + Vector3.RIGHT * 1.15):
        _fail("valid road floor rejected as an obstruction")
        return
    if not player.dismount_bike():
        _fail("safe stopped bike cannot dismount on supported roadway")
        return
    # A real car overlapping the proposed standing position must
    # still be recognized as occupied, regardless of floor tolerance.
    var car := StaticBody3D.new()
    car.collision_layer = 4
    car.position = player.global_position + Vector3(0, 0.8, 0)
    var car_cs := CollisionShape3D.new()
    var car_box := BoxShape3D.new()
    car_box.size = Vector3(0.9, 1.6, 0.9)
    car_cs.shape = car_box
    car.add_child(car_cs)
    world.add_child(car)
    await physics_frame
    if player._rider_place_clear(player.global_position):
        _fail("road-support exemption ignored solid car")
        return
    player.set_physics_process(false)
    world.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05C_GROUND_EXIT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
