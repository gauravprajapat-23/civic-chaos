extends SceneTree
## GAME-021: recover in-progress sanitation and item/bin positions from v2.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Cleanup = preload("res://scripts/civic/market_cleanup_mission.gd")
const Repo = preload("res://scripts/core/save_repository.gd")
const PATH: String = "user://game021_cleanup_checkpoint_test.json"

func _initialize() -> void:
    call_deferred("_run")

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        var candidate: String = PATH + suffix
        if FileAccess.file_exists(candidate):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))

func _world() -> Node3D:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.collision_layer = 1
    floor.position.y = -0.25
    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var shape := BoxShape3D.new()
    shape.size = Vector3(120, 0.5, 120)
    collision.shape = shape
    floor.add_child(collision)
    stage.add_child(floor)
    return stage

func _act(cleanup: CivicMarketCleanupMission, player: Node3D, kind: String, index: int, action: String) -> bool:
    var prop: CivicCleanupTarget = cleanup._target(kind, index)
    player.position = prop.position + Vector3(0, 0, 1.6)
    prop.interact(player)
    return cleanup.perform_incident_action(player, action)

func _run() -> void:
    _clean()
    var stage := _world()
    var player := Node3D.new()
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("initial civic state unavailable")
        return
    var cleanup := Cleanup.new() as CivicMarketCleanupMission
    stage.add_child(cleanup)
    if not cleanup.configure(stage, player, civic):
        _fail("physical cleanup props unavailable")
        return
    if not _act(cleanup, player, "litter", 0, "inspect"):
        _fail("evidence inspection failed")
        return
    for index in range(2):
        if not _act(cleanup, player, "litter", index, "collect_litter") or not _act(cleanup, player, "bin", -1, "deposit_litter"):
            _fail("did not fill bin before mid-service checkpoint")
            return
    if not _act(cleanup, player, "helper", -1, "request_service"):
        _fail("worker service not requested")
        return
    for frame in range(32):
        await physics_frame
    if cleanup.service_completed:
        _fail("worker arrived too quickly to test mid-service restore")
        return
    var data: Dictionary = cleanup.snapshot()
    var civic_data: Dictionary = civic.snapshot()
    if not Cleanup.checkpoint_valid(data, civic_data):
        _fail("active worker state failed save preflight")
        return
    var tampered: Dictionary = data.duplicate(true)
    tampered["bin_fill"] = 0
    if Cleanup.checkpoint_valid(tampered, civic_data):
        _fail("forged bin capacity accepted")
        return
    tampered = data.duplicate(true)
    tampered["service_completed"] = true
    if Cleanup.checkpoint_valid(tampered, civic_data):
        _fail("fabricated worker arrival accepted")
        return
    tampered = data.duplicate(true)
    tampered["item_states"][0] = 0
    if Cleanup.checkpoint_valid(tampered, civic_data):
        _fail("disposed wrapper resurrected by forged checkpoint")
        return
    if not Repo.write_save({
        "player": {"x": player.position.x, "y": 0.0, "z": player.position.z, "yaw": 0.0},
        "civic_session": civic_data, "cleanup_checkpoint": data
    }, PATH):
        _fail("checksum-verified cleanup checkpoint was not written")
        return
    var saved: Dictionary = Repo.read_save(PATH)
    if saved.is_empty() or not Cleanup.checkpoint_valid(saved.get("cleanup_checkpoint"), saved.get("civic_session")):
        _fail("saved market cleanup does not survive JSON round trip")
        return
    var original_progress: float = float(data["service_progress"])
    stage.queue_free()
    await physics_frame
    await physics_frame

    var next_stage := _world()
    var next_player := Node3D.new()
    next_stage.add_child(next_player)
    var next_civic := Session.new() as CivicGameplaySession
    next_stage.add_child(next_civic)
    if not next_civic.configure(next_stage, next_player):
        _fail("new civic world did not configure")
        return
    var next_cleanup := Cleanup.new() as CivicMarketCleanupMission
    next_stage.add_child(next_cleanup)
    if not next_cleanup.prepare_restore(next_stage, next_player, next_civic):
        _fail("new cleanup actors could not be staged without new incident")
        return
    if not next_civic.restore(saved["civic_session"]) or not next_cleanup.restore(saved["cleanup_checkpoint"]):
        _fail("real market cleanup actors could not be reconstructed")
        return
    if next_cleanup.item_states != [2, 2, 0] or next_cleanup.bin_fill != 2 or not next_cleanup.targets[2].visible:
        _fail("restored litter and bin physical states mismatch")
        return
    if absf(float(next_cleanup.snapshot()["service_progress"]) - original_progress) > 0.025:
        _fail("sanitation worker moved unexpectedly after restart")
        return
    if next_civic.missions.claim_reward(Cleanup.MISSION_ID) != 0:
        _fail("unfinished cleanup reward became claimable on restore")
        return
    for frame in range(480):
        await physics_frame
        if next_cleanup.service_completed:
            break
    if not next_cleanup.service_completed:
        _fail("restored sanitation worker did not finish route")
        return
    if not _act(next_cleanup, next_player, "litter", 2, "collect_litter") or not _act(next_cleanup, next_player, "bin", -1, "deposit_litter"):
        _fail("remaining physical wrapper could not be disposed")
        return
    if not next_cleanup.finished or not Cleanup.checkpoint_valid(next_cleanup.snapshot(), next_civic.snapshot()):
        _fail("restored cleanup did not finish coherently")
        return
    if next_civic.missions.claim_reward(Cleanup.MISSION_ID) != 0:
        _fail("restored cleanup reward was duplicated")
        return
    next_stage.queue_free()
    _clean()
    print("CIVIC_CHAOS_MARKET_CLEANUP_CHECKPOINT_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    _clean()
    quit(1)
