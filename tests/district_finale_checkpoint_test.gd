extends SceneTree
## GAME-022: disk JSON preserves acknowledged/unacknowledged Free Roam.
const Campaign = preload("res://scripts/civic/district_campaign.gd")
const Repo = preload("res://scripts/core/save_repository.gd")
const Fixture = preload("res://tests/support/campaign_fixture.gd")
const PATH: String = "user://game022_campaign_finale_checkpoint.json"

func _initialize() -> void:
    call_deferred("_run")

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        var file: String = PATH + suffix
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(file))

func _run() -> void:
    _clean()
    var fixture: Dictionary = Fixture.completed()
    if fixture.is_empty():
        _fail("campaign fixture unavailable")
        return
    var payload: Dictionary = {
        "player": {"x": 5.0, "y": 0.2, "z": -8.0, "yaw": 0.0},
        "civic_session": fixture["civic"],
        "wrong_way_checkpoint": fixture["wrong_way"],
        "parking_checkpoint": fixture["parking"],
        "cleanup_checkpoint": fixture["cleanup"],
        "campaign_checkpoint": Campaign.checkpoint(false)
    }
    if not Repo.write_save(payload, PATH):
        _fail("completed but unacknowledged finale failed to save")
        return
    var first: Dictionary = Repo.read_save(PATH)
    if not Campaign.checkpoint_valid(first.get("campaign_checkpoint"),
        first.get("civic_session"), first.get("wrong_way_checkpoint"),
        first.get("parking_checkpoint"), first.get("cleanup_checkpoint")):
        _fail("unacknowledged finale failed checkpoint preflight")
        return
    if bool(first["campaign_checkpoint"]["finale_acknowledged"]):
        _fail("save silently acknowledged the ending")
        return
    payload["campaign_checkpoint"] = Campaign.checkpoint(true)
    if not Repo.write_save(payload, PATH):
        _fail("finale acknowledgement was not persisted")
        return
    var loaded: Dictionary = Repo.read_save(PATH)
    if not Campaign.checkpoint_valid(loaded.get("campaign_checkpoint"),
        loaded.get("civic_session"), loaded.get("wrong_way_checkpoint"),
        loaded.get("parking_checkpoint"), loaded.get("cleanup_checkpoint")):
        _fail("saved Free Roam unlock lost manager consistency")
        return
    if not bool(loaded["campaign_checkpoint"]["finale_acknowledged"]):
        _fail("Free Roam acknowledgement was lost after JSON restart")
        return
    # GAME-021 completed checkpoints did not have a campaign object.
    # They must still earn Free Roam from the immutable mission ledger.
    var legacy: Dictionary = loaded.duplicate(true)
    legacy.erase("campaign_checkpoint")
    if not Campaign.can_unlock(legacy["civic_session"], legacy["wrong_way_checkpoint"],
        legacy["parking_checkpoint"], legacy["cleanup_checkpoint"]):
        _fail("completed legacy market checkpoint could not derive Free Roam")
        return
    var status: Dictionary = Repo.read_save_detail(PATH)
    if status.get("source") != "primary" or not bool(status.get("ok", false)):
        _fail("latest verified save generation was not primary")
        return
    # Simulate an interrupted primary generation to prove the exact
    # predecessor still contains a valid, not-yet-acknowledged finale.
    var tampered: Dictionary = loaded.duplicate(true)
    tampered["campaign_checkpoint"]["free_roam_unlocked"] = false
    var output := FileAccess.open(PATH, FileAccess.WRITE)
    if output == null:
        _fail("failed to stage damaged primary")
        return
    output.store_string(JSON.stringify(tampered))
    output.close()
    var backup: Dictionary = Repo.read_save_detail(PATH)
    if backup.get("source") != "backup" or not Campaign.checkpoint_valid(
        backup.get("data", {}).get("campaign_checkpoint"),
        backup.get("data", {}).get("civic_session"),
        backup.get("data", {}).get("wrong_way_checkpoint"),
        backup.get("data", {}).get("parking_checkpoint"),
        backup.get("data", {}).get("cleanup_checkpoint")):
        _fail("damaged finale save did not fall back to verified predecessor")
        return
    if bool(backup["data"]["campaign_checkpoint"]["finale_acknowledged"]):
        _fail("recoverable predecessor lost its original finale state")
        return
    _clean()
    print("CIVIC_CHAOS_DISTRICT_FINALE_CHECKPOINT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    _clean()
    quit(1)
