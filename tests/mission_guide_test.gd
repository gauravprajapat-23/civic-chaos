extends SceneTree
## GAME-015 — direction hints, clear objectives and opt-in recovery UI.
const Guide = preload("res://scripts/ui/civic_mission_guide.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var guide: CivicMissionGuide = Guide.new()
    root.add_child(guide)
    await process_frame
    var facing := Vector3(0.0, 0.0, -1.0)
    if not Guide.direction_prompt(Vector3.ZERO, facing, Vector3(0, 0, -20)).contains("AHEAD"):
        _fail("player-facing navigation failed")
        return
    if not Guide.direction_prompt(Vector3.ZERO, facing, Vector3(15, 0, 0)).contains("RIGHT"):
        _fail("right-hand navigation failed")
        return
    if not Guide.direction_prompt(Vector3.ZERO, facing, Vector3(-15, 0, 0)).contains("LEFT"):
        _fail("left-hand navigation failed")
        return
    if not Guide.direction_prompt(Vector3.ZERO, facing, Vector3(0, 0, 15)).contains("BEHIND"):
        _fail("behind navigation failed")
        return
    var actions: Array[String] = []
    guide.recovery_action_requested.connect(func(action: String) -> void:
        actions.append(action)
    )
    guide.update_guide({
        "title": "Wrong Way, Wrong Day",
        "objective": "Walk to the yellow report post.",
        "target": Vector3(0, 0, -18),
        "has_target": true,
        "speaker": "Traffic Marshal",
        "dialogue": "Stay out of the roadway.",
        "recovery_available": false
    }, Vector3.ZERO, facing)
    if not guide.mission_label.text.contains("Wrong Way") or not guide.waypoint_label.text.contains("AHEAD"):
        _fail("visible guide did not show the mission and real waypoint")
        return
    if not guide.dialogue_label.text.contains("Traffic Marshal"):
        _fail("speaker dialogue was not visible")
        return
    if guide.reload_button.visible or guide.restart_button.visible:
        _fail("recovery was offered for a healthy mission")
        return
    guide.request_reload()
    if not actions.is_empty():
        _fail("hidden retry control invoked reload")
        return
    guide.update_guide({
        "title": "Wrong Way, Wrong Day", "objective": "Traffic delayed",
        "has_target": false, "recovery_available": true,
        "recovery_reason": "No measured movement."
    }, Vector3.ZERO, facing)
    if not guide.reload_button.visible or not guide.restart_button.visible:
        _fail("stalled mission has no recovery buttons")
        return
    if not guide.help_label.text.contains("No measured movement"):
        _fail("recovery reason not displayed")
        return
    guide.request_reload()
    if actions.size() != 1 or actions[0] != "reload_checkpoint":
        _fail("reload control failed to request a checkpoint")
        return
    guide.confirmation.confirmed.emit()
    if actions.size() != 2 or actions[1] != "restart_level":
        _fail("restart did not require the confirmation pathway")
        return
    guide.queue_free()
    await process_frame
    print("CIVIC_CHAOS_MISSION_GUIDE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
