extends SceneTree

const Missions = preload("res://scripts/civic/mission_manager.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var m := Missions.new()
    assert(m.register_mission({"id": "clean_market", "reward": 50, "objectives": [{"event": "pickup_litter", "target": 2}, {"event": "report_dumping", "target": 1}]}))
    assert(not m.register_mission({"id": "clean_market", "objectives": [{"event": "x", "target": 1}]}))
    assert(m.start("clean_market"))
    assert(not m.start("clean_market"))
    assert(m.record_event("clean_market", "pickup_litter"))
    assert(m.record_event("clean_market", "pickup_litter"))
    assert(m.missions["clean_market"]["state"] == "active")
    assert(m.record_event("clean_market", "report_dumping"))
    assert(m.missions["clean_market"]["state"] == "completed")
    assert(m.claim_reward("clean_market") == 50)
    assert(m.claim_reward("clean_market") == 0)
    assert(not m.record_event("clean_market", "pickup_litter"))
    var loaded := Missions.new()
    assert(loaded.restore(m.snapshot()))
    assert(loaded.snapshot() == m.snapshot())
    assert(loaded.claim_reward("clean_market") == 0)
    assert(loaded.register_mission({"id": "timed", "objectives": [{"event": "arrive", "target": 1}]}))
    assert(loaded.start("timed"))
    assert(loaded.fail("timed"))
    assert(not loaded.record_event("timed", "arrive"))
    var path := "user://cc025_mission_test.json"
    var payload := {"player": {"x": 0.0, "y": 0.0, "z": 0.0, "yaw": 0.0}, "missions": m.snapshot()}
    assert(SaveRepo.write_save(payload, path))
    var restored := SaveRepo.read_save(path)
    assert(restored.has("missions"))
    var disk := Missions.new()
    assert(disk.restore(restored["missions"]))
    assert(disk.claim_reward("clean_market") == 0)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("CIVIC_CHAOS_MISSIONS_PASS")
    quit(0)
