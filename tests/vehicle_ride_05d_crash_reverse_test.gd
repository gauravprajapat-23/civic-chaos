extends SceneTree
## VEHICLE-RIDE-05D: after a stationary front-end crash, backing away
## must be possible without moving forward into the same collider.
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
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.collision_layer = 1
    ground.position.y = -0.3
    var floor_collision := CollisionShape3D.new()
    floor_collision.name = "CollisionShape3D"
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(40, 0.6, 40)
    floor_collision.shape = floor_box
    ground.add_child(floor_collision)
    stage.add_child(ground)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0)
    stage.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    bike.position.y = 0.15
    stage.add_child(bike)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("unobstructed bike failed to mount")
        return
    # Freeze the actual player controller to test the motion limiter at
    # a reproducible contact rather than depending on frame ordering.
    player.set_physics_process(false)
    player._bike_heading = 0.0
    var initial: Vector3 = player.global_position
    var crash := StaticBody3D.new()
    crash.name = "BuildingFace"
    crash.collision_layer = 1
    crash.position = initial + Vector3(0, 0, -1.67)
    var wall_cs := CollisionShape3D.new()
    wall_cs.name = "CollisionShape3D"
    wall_cs.position.y = 0.95
    var wall_box := BoxShape3D.new()
    wall_box.size = Vector3(1.6, 1.9, 0.5)
    wall_cs.shape = wall_box
    crash.add_child(wall_cs)
    stage.add_child(crash)
    await physics_frame
    if bike.footprint_clear_at(initial, 0.0, [player.get_rid()]):
        _fail("fixture failed to overlap bike front wheel")
        return
    player._bike_speed = 2.0
    player.velocity = Vector3(0, 0, -2)
    player._limit_bike_motion(0.05)
    if absf(player.velocity.z) > 0.001:
        _fail("bike was allowed to advance through building")
        return
    player._bike_speed = -2.0
    player.velocity = Vector3(0, 0, 2)
    player._limit_bike_motion(0.05)
    if player.velocity.z < 0.5:
        _fail("bike cannot reverse away from front crash")
        return
    # Reverse may change position, but only by the accepted step.
    player.global_position += Vector3(0, 0, 0.1)
    await physics_frame
    if bike.footprint_clear_at(player.global_position, 0.0, [player.get_rid()]):
        _fail("fixture does not preserve small initial overlap")
        return
    player._bike_speed = -2.0
    player.velocity = Vector3(0, 0, 2)
    player._limit_bike_motion(0.05)
    if player.velocity.z < 0.5:
        _fail("second reverse step was trapped by old overlap")
        return
    player.set_physics_process(false)
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05D_CRASH_REVERSE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
