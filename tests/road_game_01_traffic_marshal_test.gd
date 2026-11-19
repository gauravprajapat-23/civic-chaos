extends SceneTree
## ROAD-GAME-01 — A marshal action requires a real multi-car jam, meters
## only new arrivals, and pays only for actual cleared traffic. Inactive
## Wrong Way followers remain checkpointable but are not invisible walls.
const Assist = preload("res://scripts/civic/traffic_marshal_assist.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const WrongWay = preload("res://scripts/civic/wrong_way_live_mission.gd")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const CityMetrics = preload("res://scripts/civic/city_metrics.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var physical: Array[Dictionary] = [
        {"reason": "lead_vehicle", "position": Vector3(3, 0, 4), "streak_ticks": 88},
        {"reason": "red_signal", "position": Vector3(3, 0, 4), "streak_ticks": 300}
    ]
    var waiting: Dictionary = {"active": 7, "stopped": 4}
    if not Assist.eligible(waiting, physical, false):
        _fail("actual physical central obstruction not eligible")
        return
    if Assist.eligible(waiting, physical, true):
        _fail("rewarded incident still eligible")
        return
    var only_red: Array[Dictionary] = [
        {"reason": "red_signal", "position": Vector3(2,0,3), "streak_ticks": 900}
    ]
    if Assist.eligible(waiting, only_red, false):
        _fail("ordinary red-light queue wrongly counts as civic incident")
        return
    var distant: Array[Dictionary] = [
        {"reason": "world_collider", "position": Vector3(112,0,90), "streak_ticks": 80}
    ]
    if Assist.eligible(waiting, distant, false):
        _fail("distant unrelated blockage qualifies central intervention")
        return
    if Assist.verified(10, 11, 5, 3, 2, 0) or Assist.verified(10, 12, 5, 5, 2, 0):
        _fail("no reward should be claimed without two completed routes and queue reduction")
        return
    if Assist.verified(10, 12, 5, 3, 2, 2) or not Assist.verified(10, 12, 5, 3, 2, 1):
        _fail("central physical blockage reduction is not checked")
        return
    var metrics := CityMetrics.new()
    var baseline: int = metrics.reputation()
    if not metrics.apply_outcome(Assist.EVENT_ID, 50,
            {"safety": 10, "efficiency": 15, "cooperation": 10},
            "player_assisted_verified_vehicle_clearance"):
        _fail("measured civic reward was rejected")
        return
    var reward: int = metrics.reputation()
    if reward <= baseline or metrics.apply_outcome(Assist.EVENT_ID, 51,
            {"safety": 10, "efficiency": 15, "cooperation": 10},
            "duplicate_reputation"):
        _fail("civic ledger allowed duplicate rewards")
        return
    var saved: Dictionary = metrics.snapshot()
    var loaded := CityMetrics.new()
    if not loaded.restore(saved) or not loaded.processed_events.has(Assist.EVENT_ID):
        _fail("reputation anti-duplication did not persist in checkpoint ledger")
        return
    if loaded.apply_outcome(Assist.EVENT_ID, 51,
            {"safety": 10}, "duplicate_after_checkpoint"):
        _fail("checkpoint permitted a second marshal reward")
        return

    var stage := Node3D.new()
    root.add_child(stage)
    var spawner := Spawner.new() as CivicTrafficSpawner
    stage.add_child(spawner)
    if not spawner.configure(Builder.make_test_graph(), 150, false):
        _fail("traffic fixture failed to configure")
        return
    if spawner.request_marshal_metering(0) or spawner.request_marshal_metering(1201):
        _fail("invalid spawn hold accepted")
        return
    if not spawner.request_marshal_metering(400):
        _fail("legitimate temporary traffic metering denied")
        return
    if not spawner.marshal_metering_active() or spawner.try_spawn():
        _fail("metering did not suppress new traffic")
        return
    for tick in range(1, 400):
        spawner.advance_fixed(tick, 0.05)
    if not spawner.marshal_metering_active() or spawner.spawned_total != 0:
        _fail("metering admitted traffic before its scheduled expiry")
        return
    spawner.advance_fixed(400, 0.05)
    if spawner.marshal_metering_active():
        _fail("metering was not released after its scheduled expiry")
        return
    spawner.clear_marshal_metering()
    if spawner.marshal_metering_active():
        _fail("checkpoint reset did not remove ephemeral meter")
        return

    var follower := VehicleScene.instantiate() as CivicVehicleAgent
    stage.add_child(follower)
    var collider := follower.get_node("CollisionBody") as StaticBody3D
    follower.active = true
    WrongWay._sync_follower_presence(follower)
    if not follower.visible or collider.collision_layer != 4:
        _fail("active mission car lost its physical collider")
        return
    follower.active = false
    WrongWay._sync_follower_presence(follower)
    if follower.visible or collider.collision_layer != 0:
        _fail("route-completed mission ghost still blocks live street")
        return
    follower.active = true
    WrongWay._sync_follower_presence(follower)
    if not follower.visible or collider.collision_layer != 4:
        _fail("restoring active follower did not reenable correct collision")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_ROAD_GAME_01_TRAFFIC_MARSHAL_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
