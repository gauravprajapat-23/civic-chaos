extends SceneTree
## Safe exit must find real standing room at one SIDE of the parked
## motorcycle, not place the player inside the body or nearby traffic.
const Bike = preload("res://scripts/world/rideable_bike.gd")
const PlayerScene = preload("res://scenes/player/player_root.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _barrier(at: Vector3, name: String) -> StaticBody3D:
    var barrier := StaticBody3D.new()
    barrier.name = name
    barrier.collision_layer = 4
    barrier.collision_mask = 0
    barrier.position = at
    var cs := CollisionShape3D.new()
    cs.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(0.55, 1.6, 0.8)
    cs.shape = box
    cs.position.y = 0.85
    barrier.add_child(cs)
    return barrier

func _run() -> void:
    for action in ["move_left", "move_right", "move_forward", "move_back",
            "look_left", "look_right", "look_up", "look_down",
            "sprint", "jump", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    # Safe dismount requires verified floor support. The previous
    # standalone fixture had no ground, so the real safety check
    # correctly rejected every side even after its barriers moved.
    var road := StaticBody3D.new()
    road.name = "RoadSupport"
    road.collision_layer = 1
    road.collision_mask = 0
    road.position = Vector3(0.0, -0.30, 0.0)
    var road_shape := CollisionShape3D.new()
    road_shape.name = "CollisionShape3D"
    var road_box := BoxShape3D.new()
    road_box.size = Vector3(80.0, 0.60, 80.0)
    road_shape.shape = road_box
    road.add_child(road_shape)
    stage.add_child(road)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0, 0)
    stage.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    stage.add_child(bike)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("unobstructed bike failed to mount")
        return
    player.set_physics_process(false)
    player._bike_exit_cooldown = 0.0
    player._bike_speed = 0.0
    player.velocity = Vector3.ZERO

    var right_barrier := _barrier(Vector3(1.32, 0, 0), "RightCar")
    var left_barrier := _barrier(Vector3(-1.32, 0, 0), "LeftCar")
    stage.add_child(right_barrier)
    stage.add_child(left_barrier)
    await physics_frame
    if player.dismount_bike():
        _fail("dismounted into two occupied side exits")
        return
    if player.ridden_bike != bike:
        _fail("failed exit unexpectedly detached rider")
        return

    left_barrier.position = Vector3(-8, 0, 0)
    await physics_frame
    # A one-sided opening must not bypass either floor validation or
    # the still-occupied right-side vehicle collision.
    var support: Vector3 = player._bike_exit_support_origin()
    if not support.is_finite():
        _fail("valid road support was not detected before left-side exit")
        return
    if not player._rider_place_clear(support + Vector3.LEFT * 1.15):
        _fail("cleared left exit still fails standing capsule clearance")
        return
    if player._rider_place_clear(support + Vector3.RIGHT * 1.15):
        _fail("occupied right exit incorrectly marked safe")
        return
    if not player.dismount_bike():
        _fail("could not dismount through the newly clear left side")
        return
    if player.global_position.x > -0.8:
        _fail("player remained inside bike or moved toward blocked exit")
        return
    if bike.get_parent() != stage or bike.rider != null:
        _fail("motorcycle failed to remain parked at its actual location")
        return
    if bike.global_position.distance_to(Vector3.ZERO) > 0.01:
        _fail("bike was displaced or teleported by safe exit")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05A_SAFE_DISMOUNT_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
