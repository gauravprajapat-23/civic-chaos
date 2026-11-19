extends SceneTree
## Reverse is real backward travel, not just a negative speed variable.
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
    road.name = "Ground"
    road.collision_layer = 1
    road.position.y = -0.3
    var cs := CollisionShape3D.new()
    cs.name = "CollisionShape3D"
    var slab := BoxShape3D.new()
    slab.size = Vector3(80, 0.6, 80)
    cs.shape = slab
    road.add_child(cs)
    world.add_child(road)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0)
    world.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    world.add_child(bike)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("clear reverse test bike failed to mount")
        return
    var beginning: Vector3 = player.global_position
    var backwards: Vector3 = bike.global_transform.basis.z
    backwards.y = 0.0
    backwards = backwards.normalized()
    Input.action_press("move_back")
    for frame in range(75):
        await physics_frame
    Input.action_release("move_back")
    var displacement: Vector3 = player.global_position - beginning
    if player._bike_speed >= -0.2:
        _fail("reverse throttle failed to produce negative signed speed")
        return
    if displacement.dot(backwards) < 0.85:
        _fail("negative speed did not move bike backward: delta=%s speed=%.2f" % [
            str(displacement), player._bike_speed])
        return
    if bike._wheel_roll_total >= -0.1:
        _fail("reversing did not roll tires backward")
        return
    player.set_physics_process(false)
    world.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05D_REVERSE_TRAVEL_PASS")
    quit(0)

func _fail(message: String) -> void:
    Input.action_release("move_back")
    push_error(message)
    quit(1)
