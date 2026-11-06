extends SceneTree

const Metrics = preload("res://scripts/civic/city_metrics.gd")
const Missions = preload("res://scripts/civic/mission_manager.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var city := Metrics.new()
    assert(city.reputation() == 500)
    assert(city.apply_outcome("incident:1:resolved", 1, {"safety": 20, "trust": 10}, "incident_resolved"))
    assert(not city.apply_outcome("incident:1:resolved", 1, {"safety": 20}, "duplicate"))
    assert(city.scores["safety"] == 520)
    assert(not city.apply_outcome("bad", 2, {"trust": 101}, "too_large"))
    assert(not city.apply_outcome("unknown", 2, {"money": 10}, "invalid_dimension"))
    for tick in range(2, 9):
        assert(city.apply_outcome("penalty:%d" % tick, tick, {"efficiency": -100}, "traffic_jam"))
    assert(city.scores["efficiency"] == 0)
    var snapshot := city.snapshot()
    var loaded := Metrics.new()
    assert(loaded.restore(snapshot))
    assert(loaded.snapshot() == snapshot)
    assert(not loaded.apply_outcome("incident:1:resolved", 9, {"safety": 20}, "duplicate_after_load"))
    # JSON destroys Godot's typed-array metadata: restore must rebuild it.
    var json_history: Variant = JSON.parse_string(JSON.stringify(snapshot["history"]))
    var untyped_snapshot: Dictionary = snapshot.duplicate(true)
    untyped_snapshot["history"] = json_history
    var from_disk := Metrics.new()
    if not from_disk.restore(untyped_snapshot):
        push_error("JSON-decoded untyped civic history refused by restore")
        quit(1)
        return
    if from_disk.history.size() != city.history.size():
        push_error("Civic history entries lost after JSON round trip")
        quit(1)
        return
    if from_disk.apply_outcome("incident:1:resolved", 9, {"safety": 20}, "duplicate_after_json"):
        push_error("Duplicate civic outcome accepted after JSON round trip")
        quit(1)
        return
    var bad_history: Dictionary = untyped_snapshot.duplicate(true)
    bad_history["history"] = [{"id": "fake", "reason": "bad", "applied": {}}, 42]
    if from_disk.restore(bad_history):
        push_error("Malformed JSON audit history accepted")
        quit(1)
        return
    if from_disk.history.size() != city.history.size():
        push_error("Malformed history changed existing civic history")
        quit(1)
        return
    assert(not loaded.restore({"scores": {"safety": 9999}}))
    var missions := Missions.new()
    assert(missions.register_mission({"id": "help", "reward": 40, "objectives": [{"event": "assist", "target": 1}]}))
    assert(missions.start("help"))
    assert(missions.record_event("help", "assist"))
    assert(missions.claim_reward("help") == 40)
    assert(missions.claim_reward("help") == 0)
    assert(city.apply_outcome("mission:help:reward", 9, {"cooperation": 25}, "mission_completed"))
    assert(not city.apply_outcome("mission:help:reward", 9, {"cooperation": 25}, "repeat_reward"))
    print("CIVIC_CHAOS_CITY_METRICS_PASS")
    quit(0)
