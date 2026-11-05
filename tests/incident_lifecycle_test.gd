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
    assert(restored.next_id == m.next_id)
    assert(restored.current_tick == m.current_tick)
    assert(restored.incidents.size() == m.incidents.size())
    for id in m.incidents:
        assert(restored.incidents.has(id))
        var original_record: Dictionary = m.incidents[id]
        var restored_record: Dictionary = restored.incidents[id]
        assert(restored_record.keys().size() == original_record.keys().size())
        for key in original_record:
            assert(restored_record.has(key))
            if original_record[key] is int:
                assert(int(restored_record[key]) == int(original_record[key]))
            else:
                assert(restored_record[key] == original_record[key])
    assert(restored.event_log.size() == m.event_log.size())
    for index in range(m.event_log.size()):
        var expected_event: Dictionary = m.event_log[index]
        var actual_event: Dictionary = restored.event_log[index]
        assert(actual_event.keys().size() == expected_event.keys().size())
        for key in expected_event:
            assert(actual_event.has(key))
            if expected_event[key] is int:
                assert(int(actual_event[key]) == int(expected_event[key]))
            else:
                assert(actual_event[key] == expected_event[key])
    assert(restored.event_log.size() == 5)
    assert(Manager.from_json("broken") == null)
    print("CIVIC_CHAOS_INCIDENT_PASS")
    quit(0)
