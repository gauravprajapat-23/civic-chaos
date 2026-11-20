extends SceneTree
## VEH-RIDE-08: rider cannot walk through a parked bike, and a
## front-wheel NPC impact must not permanently disable reverse.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const BikeScript = preload("res://scripts/world/rideable_bike.gd")
var failures: int = 0

func _check(value: bool, reason: String) -> void:
    if not value:
        failures += 1
        push_error("VEH-RIDE-08: " + reason)

func _body(parent: Node3D, label: String, position: Vector3,
        layer: int, size: Vector3) -> StaticBody3D:
    var result := StaticBody3D.new()
    result.name = label
    result.position = position
    result.collision_layer = layer
    result.collision_mask = 0
    var collider := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    collider.shape = box
    result.add_child(collider)
    parent.add_child(result)
    return result

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_forward", "move_back", "move_left", "move_right",
            "look_left", "look_right", "look_up", "look_down", "jump",
            "sprint", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    _body(stage, "Floor", Vector3(0, -0.3, 0), 1,
        Vector3(35, 0.6, 35))
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.6, 0.15, 0.0)
    stage.add_child(player)
    var bike := BikeScript.new() as CivicRideableBike
    bike.position = Vector3(0, 0.15, 0)
    stage.add_child(bike)
    await physics_frame
    player.set_physics_process(false)

    # Walking collision must see the parked bike on layer 16, even though
    # the CharacterBody only collides physically with world layer 1.
    player.velocity = Vector3(-4, 0, 0)
    player._limit_horizontal_actor_motion(0.4)
    _check(player.velocity.x > -3.0,
        "walker was permitted to cross parked bike collision envelope")
    _check(player.global_position.x == 1.6,
        "walking collision guard teleported player")

    # Move to reachable, physically clear starting position.
    player.global_position = Vector3(1.2, 0.15, 0)
    await physics_frame
    _check(player.mount_bike(bike), "safe mount failed after parked contact")
    player.set_physics_process(false)
    _check(not player.visual.visible, "original walking body duplicates mounted rider")
    var rig := bike.find_child("MountedRiderRig", true, false) as CivicMotorcycleRiderRig
    _check(rig != null, "mounted rider visual rig absent")
    var start: Vector3 = player.global_position
    player._bike_heading = 0.0

    # NPC front contact: never drive deeper, but allow short retreat.
    var npc := _body(stage, "FrontPedestrian", start +
        Vector3(0, 0.89, -1.58), 8, Vector3(0.70, 1.8, 0.70))
    await physics_frame
    _check(not bike.footprint_clear_at(start, 0.0, [player.get_rid()]),
        "front NPC did not intersect the bike protection envelope")
    player._bike_speed = 2.0
    player.velocity = Vector3(0, 0, -2.0)
    player._limit_bike_motion(0.05)
    _check(absf(player.velocity.z) < 0.01,
        "front NPC contact allowed additional forward penetration")
    player._bike_speed = -2.0
    player.velocity = Vector3(0, 0, 2.0)
    player._limit_bike_motion(0.05)
    _check(player.velocity.z > 0.5,
        "NPC contact trapped bike instead of allowing backward escape")

    # A second person immediately behind the bike must stop reverse.
    var rear := _body(stage, "RearPedestrian", start +
        Vector3(0, 0.89, 1.56), 8, Vector3(0.70, 1.8, 0.70))
    await physics_frame
    player._bike_speed = -2.0
    player.velocity = Vector3(0, 0, 2.0)
    player._limit_bike_motion(0.05)
    _check(absf(player.velocity.z) < 0.01,
        "reversing into rear NPC was allowed despite collision")
    rear.queue_free()
    await physics_frame

    player._bike_speed = -2.0
    player.velocity = Vector3(0, 0, 2.0)
    player._limit_bike_motion(0.05)
    _check(player.velocity.z > 0.5,
        "reverse stayed permanently locked after rear NPC departed")
    _check(player.global_position.distance_to(start) < 0.001,
        "collision policy teleported the rider instead of limiting velocity")

    # The independent pure fallback rejects moving closer to an
    # already-overlapping NPC and large jump-out / teleport requests.
    var blockers: Array[CollisionObject3D] = [npc]
    _check(BikeScript.retreat_separates_blockers(start,
        Vector3(0, 0, 0.1), blockers, blockers),
        "conservative short backward separation rejected")
    _check(not BikeScript.retreat_separates_blockers(start,
        Vector3(0, 0, -0.1), blockers, blockers),
        "forward movement was incorrectly authorized as retreat")
    _check(not BikeScript.retreat_separates_blockers(start,
        Vector3(0, 0, 0.4), blockers, blockers),
        "large unsafe recovery displacement was allowed")
    stage.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_VEH_RIDE_08_NPC_RECOVERY_PASS")
    else:
        print("CIVIC_CHAOS_VEH_RIDE_08_NPC_RECOVERY_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
