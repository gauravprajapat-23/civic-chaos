extends SceneTree

const HUD = preload("res://scripts/ui/civic_status_hud.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var hud := HUD.new()
    root.add_child(hud)
    await process_frame
    assert(hud.traffic_label.text.contains("No live data"))
    assert(hud.reputation_label.text.contains("--"))
    assert(hud.dimensions_label.text.contains("No civic metrics"))
    var mission := {"id": "wrong_way_disaster", "state": "active", "objectives": [{"event": "report", "target": 1}], "progress": {"report": 0}}
    hud.render_state({"mission": mission, "incidents": 1, "reputation": 610, "scores": {"safety": 540, "efficiency": 620, "trust": 570, "cooperation": 710}, "traffic": {"active": 8, "queue": 3, "completed": 4}, "feedback": "Incident reported"})
    assert(hud.mission_label.text.contains("report 0/1"))
    assert(hud.traffic_label.text.contains("Queued 3"))
    assert(hud.incidents_label.text.contains("1"))
    assert(hud.reputation_label.text.contains("610"))
    assert(hud.dimensions_label.text.contains("Flow 620"))
    assert(hud.dimensions_label.text.contains("Cooperation 710"))
    assert(hud.current_state()["scores"]["trust"] == 570)
    assert(hud.feedback_label.text == "Incident reported")
    assert(hud.current_state()["mission"]["id"] == "wrong_way_disaster")
    hud.visible = false
    assert(not hud.visible)
    hud.visible = true
    assert(hud.visible)
    hud.queue_free()
    print("CIVIC_CHAOS_HUD_PASS")
    quit(0)
