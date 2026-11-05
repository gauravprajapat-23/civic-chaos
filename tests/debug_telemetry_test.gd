extends SceneTree
const Telemetry = preload("res://scripts/debug/debug_telemetry.gd")
const Overlay = preload("res://scripts/debug/debug_overlay.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var t := Telemetry.new()
    assert(t.record(1, {"active": 2}, {"vehicle_1": [1, 2]}, {"count": 1}, {"choice": "wait"}, {"cycles": []}, {"ai_ms": 0.5}))
    assert(not t.record(1, {}, {}, {}, {}, {}, {}))
    assert(not t.record(2, {"bad": Vector3.ONE}, {}, {}, {}, {}, {}))
    assert(t.export_document()["schema_version"] == 1)
    assert(t.export_json("user://civic_debug_test.json"))
    var raw := FileAccess.get_file_as_string("user://civic_debug_test.json")
    var parsed: Variant = JSON.parse_string(raw)
    assert(parsed is Dictionary)
    assert(parsed["sample_count"] == 1)
    assert(parsed["samples"][0]["routes"]["vehicle_1"] == [1, 2])
    var overlay := Overlay.new()
    root.add_child(overlay)
    await process_frame
    assert(not overlay.enabled)
    overlay.set_enabled(true)
    assert(overlay.panel.visible)
    assert(overlay.record_snapshot(3, {"active": 1}, {}, {}, {}, {}, {}))
    assert(overlay.output.text.contains("Tick 3"))
    overlay.set_enabled(false)
    assert(not overlay.panel.visible)
    overlay.queue_free()
    print("CIVIC_CHAOS_DEBUG_TELEMETRY_PASS")
    quit(0)
