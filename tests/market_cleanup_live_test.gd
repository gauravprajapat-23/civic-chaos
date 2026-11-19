extends SceneTree
## GAME-021: real litter pickup, two-slot bin, worker travel and one reward.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Cleanup = preload("res://scripts/civic/market_cleanup_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _world() -> Node3D:
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.name = "Ground"
    ground.collision_layer = 1
    ground.position.y = -0.25
    var collider := CollisionShape3D.new()
    collider.name = "CollisionShape3D"
    var shape := BoxShape3D.new()
    shape.size = Vector3(120, 0.5, 120)
    collider.shape = shape
    ground.add_child(collider)
    stage.add_child(ground)
    return stage

func _act(cleanup: CivicMarketCleanupMission, player: Node3D, kind: String, slot: int, action: String) -> bool:
    var target: CivicCleanupTarget = cleanup._target(kind, slot)
    player.position = target.position + Vector3(0, 0, 1.5)
    var before: Dictionary = cleanup.snapshot()
    target.interact(player)
    match action:
        "inspect":
            return cleanup.inspected
        "collect_litter":
            return cleanup.carried_index == slot and cleanup.item_states[slot] == 1
        "deposit_litter":
            return cleanup.deposited_count == int(before["deposited_count"]) + 1
        "request_service":
            return cleanup.service_requested_tick >= 0 and int(before["service_requested_tick"]) < 0
    return false

func _run() -> void:
    var stage := _world()
    var player := Node3D.new()
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic managers did not configure")
        return
    var cleanup := Cleanup.new() as CivicMarketCleanupMission
    stage.add_child(cleanup)
    if not cleanup.configure(stage, player, civic):
        _fail("cleanup scenario did not stage")
        return
    if not Cleanup.checkpoint_valid(cleanup.snapshot(), civic.snapshot()):
        _fail("initial cleanup checkpoint invalid")
        return
    if _act(cleanup, player, "helper", -1, "request_service"):
        _fail("service called before bin was full")
        return
    if cleanup.inspected:
        _fail("litter evidence was pre-inspected before E")
        return
    if not _act(cleanup, player, "litter", 0, "collect_litter"):
        _fail("E did not inspect and collect the first wrapper")
        return
    if not cleanup.inspected or int(civic.missions.missions[Cleanup.MISSION_ID]["progress"]["litter_evidence"]) != 1:
        _fail("first E pickup did not record real evidence once")
        return
    if cleanup.targets[0].visible or cleanup.targets[0].collision_layer != 0:
        _fail("collected wrapper still lies on the street")
        return
    if _act(cleanup, player, "litter", 1, "collect_litter"):
        _fail("player held two wrappers at once")
        return
    if not _act(cleanup, player, "bin", -1, "deposit_litter"):
        _fail("first wrapper was not physically deposited")
        return
    if not _act(cleanup, player, "litter", 1, "collect_litter") or not _act(cleanup, player, "bin", -1, "deposit_litter"):
        _fail("second wrapper did not fill the bin")
        return
    if cleanup.bin_fill != Cleanup.BIN_CAPACITY or cleanup.deposited_count != 2:
        _fail("bin occupancy was not measured")
        return
    if not _act(cleanup, player, "litter", 2, "collect_litter"):
        _fail("third wrapper could not be collected")
        return
    if _act(cleanup, player, "bin", -1, "deposit_litter"):
        _fail("overfilled bin accepted an extra wrapper")
        return
    if cleanup.finished or civic.missions.claim_reward(Cleanup.MISSION_ID) != 0:
        _fail("unserved cleanup awarded rewards early")
        return
    if not _act(cleanup, player, "helper", -1, "request_service"):
        _fail("full-bin sanitation request was not accepted")
        return
    if _act(cleanup, player, "helper", -1, "request_service"):
        _fail("sanitation service requested twice")
        return
    for frame in range(480):
        await physics_frame
        if cleanup.service_completed:
            break
    if not cleanup.service_completed or cleanup.helper.position.distance_to(Cleanup.HELPER_DESTINATION) > 0.025:
        _fail("worker never physically reached and emptied bin")
        return
    if cleanup.bin_fill != 0 or int(civic.missions.missions[Cleanup.MISSION_ID]["progress"]["bin_serviced"]) != 1:
        _fail("physical sanitation did not release bin capacity exactly once")
        return
    if not _act(cleanup, player, "bin", -1, "deposit_litter"):
        _fail("last wrapper could not be deposited after service")
        return
    if not cleanup.finished or cleanup.deposited_count != 3 or cleanup.bin_fill != 1:
        _fail("all-litter cleanup recovery was not measured")
        return
    if civic.metrics.scores["cooperation"] != 525 or civic.metrics.scores["trust"] != 515 or civic.metrics.scores["efficiency"] != 510:
        _fail("final civic score differs from physical cleanup outcome")
        return
    if civic.missions.claim_reward(Cleanup.MISSION_ID) != 0:
        _fail("cleanup reward collected more than once")
        return
    if not Cleanup.checkpoint_valid(JSON.parse_string(JSON.stringify(cleanup.snapshot())), civic.snapshot()):
        _fail("completed cleanup checkpoint failed JSON roundtrip")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_MARKET_CLEANUP_LIVE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
