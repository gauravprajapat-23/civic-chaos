extends SceneTree
## Check persisted civic session, score/reward idempotence and corrupt payload rejection.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Lifecycle = preload("res://scripts/core/game_lifecycle.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")
const SAVE_PATH := "user://civic_gameplay_persistence_test.json"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    player.position = Vector3(5.0, 0.21, -12.0)
    stage.add_child(player)
    var session = Session.new()
    stage.add_child(session)
    if not session.configure(stage, player):
        _fail("initial civic session failed")
        return
    if not session.try_interact_at_marker(player) or not session.try_interact_at_marker(player):
        _fail("could not inspect and report")
        return
    var saving := Lifecycle.new()
    stage.add_child(saving)
    var payload: Dictionary = session.snapshot()
    if not saving.save_player(player, SAVE_PATH, {"civic_session": payload}):
        _fail("composite save failed")
        return
    var loaded: Dictionary = SaveRepo.read_save(SAVE_PATH)
    if loaded.is_empty() or not loaded.has("civic_session"):
        _fail("civic snapshot missing from player save")
        return
    var invalid: Dictionary = loaded["civic_session"].duplicate(true)
    invalid["finished"] = true # Cannot be completed before actual cleanup.
    if session.can_restore(invalid):
        _fail("inconsistent completed save accepted")
        return
    invalid = loaded["civic_session"].duplicate(true)
    invalid["schema_version"] = 999
    if session.can_restore(invalid):
        _fail("future unsupported session schema was accepted")
        return
    var resumed = Session.new()
    stage.add_child(resumed)
    if not resumed.configure(stage, player) or not resumed.restore(loaded["civic_session"]):
        _fail("legitimate pending report failed to restore")
        return
    if resumed.reported_tick < 0 or resumed.incidents.incidents[resumed.incident_id]["state"] != CivicIncidentManager.ESCALATED:
        _fail("restored report state was lost")
        return
    if resumed.metrics.history.size() != session.metrics.history.size():
        _fail("restored civic metrics audit history did not match the saved history")
        return
    if resumed.try_interact_at_marker(player):
        _fail("restored incident allowed duplicate reporting")
        return
    # Stop the original scenario so only the restored session advances.
    session.set_physics_process(false)
    for frame in range(160):
        await physics_frame
    if not resumed.finished:
        _fail("restored service never cleared the obstruction")
        return
    var done: Dictionary = resumed.snapshot()
    if not resumed.can_restore(done):
        _fail("legitimate completed snapshot rejected")
        return
    if resumed.metrics.history.size() != 1:
        _fail("completed mission must have one auditable civic outcome")
        return
    # Exercise a real disk round trip AFTER an outcome exists, not just an
    # in-memory typed Array[Dictionary]. This reproduces the reported failure.
    if not saving.save_player(player, SAVE_PATH, {"civic_session": done}):
        _fail("completed civic checkpoint failed to save")
        return
    var completed_file: Dictionary = SaveRepo.read_save(SAVE_PATH)
    if not completed_file.has("civic_session"):
        _fail("completed civic checkpoint missing from disk")
        return
    var replay = Session.new()
    stage.add_child(replay)
    if not replay.configure(stage, player) or not replay.restore(completed_file["civic_session"]):
        _fail("completed JSON civic checkpoint failed to restore")
        return
    if replay.metrics.history.size() != 1:
        _fail("civic outcome history lost from completed JSON checkpoint")
        return
    await process_frame
    if is_instance_valid(replay.marker):
        _fail("completed session incorrectly recreated world obstruction")
        return
    if replay.metrics.scores["efficiency"] != 525 or replay.metrics.scores["cooperation"] != 515:
        _fail("reloaded city reputation changed")
        return
    if replay.missions.claim_reward(Session.MISSION_ID) != 0:
        _fail("reward farmed after reloading")
        return
    stage.queue_free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    print("CIVIC_CHAOS_GAMEPLAY_PERSISTENCE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    quit(1)
