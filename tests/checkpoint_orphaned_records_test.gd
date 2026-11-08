extends SceneTree
## AUD-001: signed player-only legacy saves must not smuggle ignored world,
## campaign, mission or Free Roam state through the early return in F9.
const Main = preload("res://scripts/core/main.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")
const PATH: String = "user://aud001_checkpoint_orphaned_records.json"

func _initialize() -> void:
    call_deferred("_run")

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        var path: String = PATH + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
    _clean()
    var legacy: Dictionary = {
        "player": {"x": 1.0, "y": 0.2, "z": 2.0, "yaw": 0.0}
    }
    if not SaveRepo.write_save(legacy, PATH) or not Main.checkpoint_envelope_valid(SaveRepo.read_save(PATH)):
        _fail("valid player-only save was rejected")
        return
    var orphaned_records: Array[String] = [
        "wrong_way_checkpoint", "parking_checkpoint",
        "cleanup_checkpoint", "campaign_checkpoint",
        "free_roam_checkpoint", "world_checkpoint"
    ]
    for name in orphaned_records:
        var orphaned: Dictionary = legacy.duplicate(true)
        orphaned[name] = {"schema_version": 1}
        # These are legitimate checksummed v2 JSON documents; the bug was
        # their game-level meaning, not damaged data or invalid signatures.
        if not SaveRepo.write_save(orphaned, PATH):
            _fail("failed to write signed orphan fixture: " + name)
            return
        var read_back: Dictionary = SaveRepo.read_save(PATH)
        if read_back.is_empty() or not Main.checkpoint_record_types_valid(read_back):
            _fail("orphan fixture is not a valid signed dictionary record: " + name)
            return
        if Main.checkpoint_envelope_valid(read_back):
            _fail("loader accepted orphaned record without civic_session: " + name)
            return

    var civic: Dictionary = legacy.duplicate(true)
    civic["civic_session"] = {"schema_version": 1}
    civic["world_checkpoint"] = {"schema_version": 1}
    if not SaveRepo.write_save(civic, PATH):
        _fail("could not write fully parented civic checkpoint")
        return
    if not Main.checkpoint_envelope_valid(SaveRepo.read_save(PATH)):
        _fail("properly parented civic and world record failed envelope validation")
        return
    var malformed: Dictionary = civic.duplicate(true)
    malformed["world_checkpoint"] = 42
    if Main.checkpoint_envelope_valid(malformed):
        _fail("invalid world record type bypassed envelope validation")
        return
    _clean()
    print("CIVIC_CHAOS_CHECKPOINT_ORPHANED_RECORDS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    _clean()
    quit(1)
