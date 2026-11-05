extends SceneTree

const Manager = preload("res://scripts/civic/incident_manager.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var m := Manager.new()
    var first := m.create_incident("littering", 7, 1, "market")
    assert(first["ok"])
    assert(not first["duplicate"])
    var duplicate := m.create_incident("littering", 7, 1, "market")
    assert(duplicate["duplicate"])
    assert(duplicate["id"] == first["id"])
    assert(not m.transition(first["id"], "resolved", 2, "unsupported"))
    assert(m.transition(first["id"], "escalated", 2, "repeat_offense"))
    assert(m.transition(first["id"], "intervention", 3, "community_warning"))
    assert(m.transition(first["id"], "resolved", 4, "cleanup_completed"))
    assert(not m.transition(first["id"], "active", 5, "invalid"))
    var next := m.create_incident("littering", 7, 5, "market")
    assert(next["id"] != first["id"])
    var restored := Manager.from_json(m.to_json())
    assert(restored != null)
    assert(restored.snapshot() == m.snapshot())
    assert(restored.event_log.size() == 5)
    assert(Manager.from_json("broken") == null)
    print("CIVIC_CHAOS_INCIDENT_PASS")
    quit(0)
