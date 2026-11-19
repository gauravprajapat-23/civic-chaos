extends SceneTree
## VEHICLE-RIDE-05D: mounted visual brake dive remains cosmetic and
## standing-room computation recovers minor ground penetration only.
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
    var cs := CollisionShape3D.new()
    cs.name = "CollisionShape3D"
    var road_box := BoxShape3D.new()
    road_box.size = Vector3(80, 0.6, 80)
    cs.shape = road_box
    road.add_child(cs)
    world.add_child(road)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0)
    world.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    world.add_child(bike)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("clean road mount failed")
        return
    player.set_physics_process(false)
    player._bike_exit_cooldown = 0.0
    player._bike_speed = 0.0
    player.velocity = Vector3.ZERO
    player.global_position.y = -0.12
    await physics_frame
    if not player._bike_exit_support_origin().is_finite():
        _fail("road support lost for small rider grounding offset")
        return
    if not player.dismount_bike():
        _fail("grounded bike exit failed")
        return
    if not is_equal_approx(player.spring_arm.spring_length, 4.0):
        _fail("chase camera did not restore walking distance")
        return
    var interaction := bike.get_node("InteractionShape") as CollisionShape3D
    var original: Transform3D = interaction.transform
    for frame in range(15):
        bike.update_ride_visuals(1.0, 8.0, 0.05, 0.0)
    var rig := bike.find_child("VisualRig", true, false) as Node3D
    if rig == null or rig.rotation.x >= -0.008 or interaction.transform != original:
        _fail("brake dive missing or affected collision")
        return
    for frame in range(20):
        bike.update_ride_visuals(0.0, 0.0, 0.05, 0.0)
    if absf(rig.rotation.x) > 0.01:
        _fail("brake dive did not recover")
        return
    world.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05D_CAMERA_SUSPENSION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
