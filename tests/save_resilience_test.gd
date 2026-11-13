extends SceneTree
## GAME-018: actual file generations, legacy migration and crash recovery.
const Repo = preload("res://scripts/core/save_repository.gd")
const PATH: String = "user://game018_save_resilience_test.json"

func _initialize() -> void:
    call_deferred("_run")

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        var path: String = PATH + suffix
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _sample(x: float) -> Dictionary:
    return {"player": {"x": x, "y": 0.1, "z": 2.0, "yaw": 0.0},
        "civic_session": {"test_generation": int(x)}}

func _overwrite(path: String, document: Dictionary) -> bool:
    var output := FileAccess.open(path, FileAccess.WRITE)
    if output == null:
        return false
    output.store_string(JSON.stringify(document))
    output.close()
    return true

func _run() -> void:
    _clean()
    if not Repo.write_save(_sample(1.0), PATH):
        _fail("generation A not saved")
        return
    var a: Dictionary = Repo.read_save_detail(PATH)
    if a.get("source") != "primary" or a.get("data", {}).get("version") != 2 or not (a["data"].get("checksum") is String):
        _fail("new generation has no verified v2 signature")
        return
    if not Repo.write_save(_sample(2.0), PATH):
        _fail("generation B not saved")
        return
    var primary: Dictionary = Repo.read_save_detail(PATH)
    if primary.get("source") != "primary" or float(primary["data"]["player"]["x"]) != 2.0:
        _fail("latest committed generation not read")
        return
    if Repo._read_one(PATH + ".bak").get("player", {}).get("x") != 1.0:
        _fail("last-known-good generation A backup missing")
        return

    # A tmp file was never committed, even if it is readable JSON.
    if not _overwrite(PATH + ".tmp", {"version": 1, "player": _sample(99.0)["player"]}):
        _fail("test interrupted temporary file creation failed")
        return
    if Repo.read_save_detail(PATH).get("source") != "primary" or Repo.read_save(PATH)["player"]["x"] != 2.0:
        _fail("interrupted uncommitted temporary generation was loaded")
        return

    var tampered: Dictionary = Repo.read_save(PATH).duplicate(true)
    tampered["player"]["x"] = 400.0 # Keep original checksum deliberately.
    if not _overwrite(PATH, tampered):
        _fail("test checksum tamper failed")
        return
    var fallback: Dictionary = Repo.read_save_detail(PATH)
    if fallback.get("source") != "backup" or float(fallback["data"]["player"]["x"]) != 1.0:
        _fail("tampered primary did not fall back to previous valid generation")
        return
    if not Repo.write_save(_sample(3.0), PATH):
        _fail("new primary generation after corruption failed")
        return
    if float(Repo._read_one(PATH + ".bak").get("player", {}).get("x", -1)) != 1.0:
        _fail("corrupt primary overwrote the last good backup")
        return
    var broken := FileAccess.open(PATH, FileAccess.WRITE)
    if broken == null:
        _fail("could not simulate truncated JSON")
        return
    broken.store_string("{not complete")
    broken.close()
    if Repo.read_save_detail(PATH).get("source") != "backup":
        _fail("truncated JSON did not recover from previous backup")
        return
    if not _overwrite(PATH + ".bak", {"version": 99, "player": _sample(9.0)["player"]}):
        _fail("invalid backup test couldn't write")
        return
    if not Repo.read_save(PATH).is_empty():
        _fail("invalid primary and backup produced fabricated recovery")
        return

    # v1 files from older releases stay readable but are upgraded on WRITE,
    # not silently changed when read. Their old data becomes the v2 backup.
    _clean()
    if not _overwrite(PATH, {"version": 1, "player": _sample(10.0)["player"]}):
        _fail("legacy fixture couldn't write")
        return
    if int(Repo.read_save(PATH).get("version", -1)) != 1:
        _fail("valid old save version rejected")
        return
    if not Repo.write_save(_sample(11.0), PATH):
        _fail("legacy to verified v2 upgrade failed")
        return
    if int(Repo.read_save(PATH).get("version", -1)) != 2:
        _fail("legacy save was not upgraded on next commit")
        return
    if int(Repo._read_one(PATH + ".bak").get("version", -1)) != 1:
        _fail("legacy predecessor not retained in backup")
        return
    var valid_v2: Dictionary = Repo.read_save(PATH)
    valid_v2["version"] = 3
    if not _overwrite(PATH, valid_v2):
        _fail("future-version fixture couldn't write")
        return
    var status: Dictionary = Repo.read_save_detail(PATH)
    if status.get("source") != "backup" or int(status["data"]["version"]) != 1:
        _fail("unknown save version not rejected in favour of valid legacy backup")
        return
    if Repo.write_save({"version": 1, "player": _sample(4.0)["player"]}, PATH):
        _fail("write path accepted caller-controlled format downgrade")
        return
    if Repo.write_save({"checksum": "fake", "player": _sample(4.0)["player"]}, PATH):
        _fail("write path accepted caller-controlled checksum")
        return
    if Repo.read_save_detail(PATH).get("source") != "backup":
        _fail("refused writes changed the committed backup recovery")
        return

    _clean()
    print("CIVIC_CHAOS_SAVE_RESILIENCE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    _clean()
    quit(1)
