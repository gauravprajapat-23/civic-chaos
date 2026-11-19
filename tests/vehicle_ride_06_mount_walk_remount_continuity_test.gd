extends SceneTree
## VEH-002: mount -> seated idle -> safe exit -> walk -> remount.
## Checks pose/camera continuity and fork-bound hands without bypassing
## any rider clearance, traffic, or bike footprint physics checks.
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
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(80, 0.6, 80)
    collision.shape = shape
    ground.add_child(collision)
    world.add_child(ground)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0.0)
    world.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    world.add_child(bike)
    await physics_frame
    var original_height: float = player.camera_pivot.position.y
    var original_length: float = player.spring_arm.spring_length
    if not player.mount_bike(bike):
        _fail("mount rejected on clear pavement")
        return
    for frame in range(30):
        await physics_frame
    var rig := bike.find_child("MountedRiderRig", true, false) as CivicMotorcycleRiderRig
    var fork := bike.find_child("SteeringFork", true, false) as Node3D
    if rig == null or fork == null or player.visual.visible:
        _fail("mounted rider rig missing or duplicate walking mesh visible")
        return
    if rig.get_node_or_null("RiderHead") == null:
        _fail("original character appearance was not copied to mounted rider")
        return
    bike.update_ride_visuals(1.0, 7.0, 0.1, 0.25)
    for side in ["Left", "Right"]:
        var hand := rig.get_node(side + "Hand") as MeshInstance3D
        var target := fork.get_node(side + "GripTarget") as Marker3D
        if hand.global_position.distance_to(target.global_position) > 0.005:
            _fail("steered hand detached from handlebar: " + side)
            return
    player.set_physics_process(false)
    player._bike_exit_cooldown = 0.0
    player._bike_speed = 0.0
    player.velocity = Vector3.ZERO
    player.global_position.y = -0.10
    await physics_frame
    if not player.dismount_bike():
        _fail("clear stopped bike rejected side exit")
        return
    if player.ridden_bike != null or bike.rider != null or bike.get_parent() != world:
        _fail("dismount failed to transfer bike ownership")
        return
    if not player.visual.visible or not player._bike_camera_recovering:
        _fail("on-foot mesh/camera handoff was not started")
        return
    if not is_equal_approx(player._bike_pose_blend, 0.0):
        _fail("seated pose remains active after dismount")
        return
    for limb_name in ["LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
        var limb := player.visual.get_node(limb_name) as Node3D
        if absf(limb.rotation.x) > 0.001:
            _fail("mounted limb leaked into walking pose: " + limb_name)
            return
    var exit_position: Vector3 = player.global_position
    player.set_physics_process(true)
    Input.action_press("move_forward")
    for frame in range(12):
        await physics_frame
    Input.action_release("move_forward")
    if player.global_position.distance_to(exit_position) < 0.03:
        _fail("walking movement unavailable after dismount")
        return
    if player._bike_pose_blend > 0.001:
        _fail("walk tick reapplied seated pose")
        return
    for frame in range(70):
        await physics_frame
    if absf(player.spring_arm.spring_length - original_length) > 0.01 or (
            absf(player.camera_pivot.position.y - original_height) > 0.01):
        _fail("walk camera did not recover original spring/height")
        return
    if player._bike_dismount_height_blend > 0.001 or (
            absf(player.visual.position.y - 0.9) > 0.001):
        _fail("on-foot character remained elevated after transition")
        return
    # The walker should remain within genuine interaction distance.
    if player.global_position.distance_to(bike.global_position) > CivicRideableBike.MOUNT_DISTANCE_M:
        _fail("walk fixture moved outside mount range")
        return
    if not player.mount_bike(bike):
        _fail("safe remount failed after walking")
        return
    if bike.rider != player or player.visual.visible:
        _fail("remount failed to restore single mounted rider owner")
        return
    player.set_physics_process(false)
    world.queue_free()
    print("CIVIC_CHAOS_VEH_002_MOUNT_WALK_REMOUNT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    Input.action_release("move_forward")
    push_error(reason)
    quit(1)
