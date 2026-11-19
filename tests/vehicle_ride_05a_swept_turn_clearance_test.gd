extends SceneTree
## Bike guard must detect a long front wheel collision and a side-swipe
## introduced by yaw, even when a short walking capsule is still clear.
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
    var player := PlayerScene.instantiate() as CivicPlayerController
    stage.add_child(player)
    player.set_physics_process(false)
    var bike := Bike.new() as CivicRideableBike
    stage.add_child(bike)
    var obstacle := StaticBody3D.new()
    obstacle.name = "StationaryCityCar"
    obstacle.collision_layer = 4
    obstacle.collision_mask = 0
    var cs := CollisionShape3D.new()
    cs.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(1.6, 1.2, 3.0)
    cs.shape = box
    cs.position = Vector3(0, 0.7, 0)
    obstacle.add_child(cs)
    stage.add_child(obstacle)
    await physics_frame

    # Straight bike initially has a narrow clearance on its right.
    obstacle.position = Vector3(1.8, 0, -1.1)
    await physics_frame
    if not bike.footprint_clear_at(Vector3.ZERO, 0.0, [player.get_rid()]):
        _fail("bike guard reported clear straight pose as blocked")
        return
    if bike.footprint_clear_at(Vector3.ZERO, -0.48, [player.get_rid()]):
        _fail("bike front wheel swung sideways into car while turning right")
        return

    # A full bike reaches the car BEFORE the player's 0.7m capsule.
    obstacle.position = Vector3(0, 0, -3.5)
    await physics_frame
    if not bike.footprint_clear_at(Vector3.ZERO, 0.0, [player.get_rid()]):
        _fail("bike initial straight footprint is already overlapping")
        return
    var request := bike._make_footprint_query(
        Vector3.ZERO, 0.0, Vector3(0, 0, -2), [player.get_rid()])
    var fractions: PackedFloat32Array = bike.get_world_3d().direct_space_state.cast_motion(request)
    if fractions.size() < 1 or fractions[0] >= 0.8:
        _fail("full wheelbase swept too far through car before stopping")
        return
    if request.shape != bike._footprint_shape:
        _fail("sweep and parked full-footprint validation use different geometry")
        return
    if not is_equal_approx(bike._footprint_shape.size.z, Bike.FOOTPRINT_SIZE.z):
        _fail("full collision envelope is shorter than motorcycle wheelbase")
        return
    player.set_physics_process(false)
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05A_SWEPT_TURN_CLEARANCE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
