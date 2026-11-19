extends SceneTree
## Repeated mounting on roadway must remain possible after settling.
## The bike's full vehicle footprint still rejects real traffic colliders.
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
    road.position.y = -0.3
    road.collision_layer = 1
    var floor_cs := CollisionShape3D.new()
    floor_cs.name = "CollisionShape3D"
    var slab := BoxShape3D.new()
    slab.size = Vector3(80, 0.6, 80)
    floor_cs.shape = slab
    road.add_child(floor_cs)
    world.add_child(road)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0)
    world.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    world.add_child(bike)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("initial bike mount failed")
        return
    player.set_physics_process(false)
    player._bike_exit_cooldown = 0.0
    player._bike_speed = 0.0
    player.velocity = Vector3.ZERO
    player.global_position.y = -0.10
    await physics_frame
    if not player.dismount_bike():
        _fail("park failed after supported ride")
        return
    # Dismount must release the seated limb pose before walking resumes.
    for limb_name in ["LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
        var limb := player.visual.get_node_or_null(limb_name) as Node3D
        if limb == null:
            _fail("missing walking limb: " + limb_name)
            return
        if absf(limb.rotation.x) > 0.001:
            _fail("seated limb pose persisted after dismount: " + limb_name)
            return
    if not player.visual.visible:
        _fail("walking character remained hidden after dismount")
        return
    if bike.get_parent() != world:
        _fail("bike was not parked in world")
        return
    if player.mount_bike(bike):
        _fail("remount cooldown bypassed")
        return
    player._bike_exit_cooldown = 0.0
    await physics_frame
    if not player.mount_bike(bike):
        _fail("remount rejected on unobstructed roadway")
        return
    if bike.rider != player:
        _fail("remount did not restore rider ownership")
        return
    player.set_physics_process(false)
    world.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05D_REMOUNT_CYCLE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
