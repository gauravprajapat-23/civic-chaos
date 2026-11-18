extends SceneTree
## Bike must back away from a pedestrian already touching the front tire.
## A full 05A footprint still prevents driving FORWARD through the person.
const Bike = preload("res://scripts/world/rideable_bike.gd")
const PlayerScene = preload("res://scenes/player/player_root.tscn")

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
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0, 0)
    stage.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    stage.add_child(bike)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("mount before pedestrian crash failed")
        return
    player.set_physics_process(false)
    var pedestrian := StaticBody3D.new()
    pedestrian.name = "PedestrianContact"
    pedestrian.collision_layer = 8
    pedestrian.collision_mask = 0
    pedestrian.position = player.global_position + Vector3(0, 0, -1.65)
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    shape.position.y = 1.0
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.3
    capsule.height = 1.8
    shape.shape = capsule
    pedestrian.add_child(shape)
    stage.add_child(pedestrian)
    await physics_frame
    if bike.footprint_clear_at(player.global_position, 0.0, [player.get_rid()]):
        _fail("pedestrian front contact not detected")
        return
    player._bike_heading = 0.0
    player._bike_speed = 2.0
    player.velocity = Vector3(0, 0, -2)
    player._limit_bike_motion(0.05)
    if absf(player.velocity.z) > 0.001:
        _fail("motorcycle permitted forward motion through pedestrian")
        return
    player._bike_speed = -2.0
    player.velocity = Vector3(0, 0, 2)
    player._limit_bike_motion(0.05)
    if player.velocity.z < 0.5:
        _fail("motorcycle trapped instead of reversing away from pedestrian")
        return
    player.set_physics_process(false)
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05D_PEDESTRIAN_CRASH_REVERSE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
