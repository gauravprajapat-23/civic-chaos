extends SceneTree
## AUD-001: a valid checksum cannot make malformed nested campaign data safe.
## Reject wrong field types before mission .get(), restore, or actor staging.
const Main = preload("res://scripts/core/main.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")
const PATH: String = "user://aud001_checkpoint_record_shapes.json"

func _initialize() -> void:
    call_deferred("_run")

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        var location: String = PATH + suffix
        if FileAccess.file_exists(location):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(location))

func _run() -> void:
    _clean()
    var legacy: Dictionary = {"player": {"x": 0.0, "y": 0.1, "z": 0.0, "yaw": 0.0}}
    if not Main.checkpoint_record_types_valid(legacy):
        _fail("legacy player-only checkpoint was rejected")
        return
    var records: Array[String] = [
        "civic_session", "wrong_way_checkpoint", "parking_checkpoint",
        "cleanup_checkpoint", "campaign_checkpoint", "free_roam_checkpoint",
        "world_checkpoint"
    ]
    for record in records:
        var valid: Dictionary = legacy.duplicate(true)
        valid[record] = {}
        if not Main.checkpoint_record_types_valid(valid):
            _fail("dictionary record was rejected: " + record)
            return
        for invalid in [null, true, 17, "forged", []]:
            var malformed: Dictionary = valid.duplicate(true)
            malformed[record] = invalid
            if Main.checkpoint_record_types_valid(malformed):
                _fail("wrong typed nested checkpoint was accepted: " + record)
                return

    # SaveRepo signs only the player envelope and checksum; it is a separate
    # stage validator's job to reject bad types in the campaign/world records.
    var signed_invalid: Dictionary = legacy.duplicate(true)
    signed_invalid["campaign_checkpoint"] = 17
    if not SaveRepo.write_save(signed_invalid, PATH):
        _fail("could not produce a correctly checksummed malformed fixture")
        return
    var loaded: Dictionary = SaveRepo.read_save(PATH)
    if loaded.is_empty() or int(loaded.get("campaign_checkpoint", -1)) != 17:
        _fail("checksummed malformed fixture was not read")
        return
    if Main.checkpoint_record_types_valid(loaded):
        _fail("valid checksum incorrectly bypassed nested shape validation")
        return

    var signed_valid: Dictionary = legacy.duplicate(true)
    signed_valid["campaign_checkpoint"] = {"schema_version": 1}
    if not SaveRepo.write_save(signed_valid, PATH):
        _fail("could not save a correctly typed checkpoint")
        return
    if not Main.checkpoint_record_types_valid(SaveRepo.read_save(PATH)):
        _fail("correctly typed verified save was rejected")
        return
    _clean()
    print("CIVIC_CHAOS_CHECKPOINT_RECORD_SHAPES_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    _clean()
    quit(1)
