extends SceneTree
## GAME-QA-01: viewport geometry and core mission guidance remain usable.
const Guide = preload("res://scripts/ui/civic_mission_guide.gd")
const HUD = preload("res://scripts/ui/civic_status_hud.gd")
const Card = preload("res://scripts/ui/civic_incident_card.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for dimensions in [
        Vector2(320, 568), Vector2(360, 740), Vector2(740, 360),
        Vector2(1280, 720), Vector2(1920, 1080)
    ]:
        var guide: Rect2 = Guide.panel_bounds(dimensions)
        if guide.size.x < 200.0 or guide.size.y < 100.0:
            _fail("mission guide too small at " + str(dimensions))
            return
        if guide.position.x < 0.0 or guide.position.y < 0.0 or guide.end.x > dimensions.x or guide.end.y > dimensions.y:
            _fail("mission guide escaped visible viewport " + str(dimensions))
            return
        if Guide.panel_bounds(dimensions) != guide:
            _fail("mission guide geometry is nondeterministic")
            return
        var hud: Rect2 = HUD.layout_for(dimensions)
        var card: Vector2 = Card.panel_bounds(dimensions)
        if hud.end.x > dimensions.x or card.x > dimensions.x:
            _fail("existing civic overlay exceeds viewport")
            return
        if guide.intersects(hud):
            _fail("mission guide overlaps civic HUD at " + str(dimensions))
            return
    if Guide.panel_bounds(Vector2(INF, 720)) != Rect2():
        _fail("invalid mission guide viewport accepted")
        return

    var stage := Node.new()
    root.add_child(stage)
    var guide_node := Guide.new() as CivicMissionGuide
    stage.add_child(guide_node)
    await process_frame
    var rect: MarginContainer = guide_node.get_node_or_null("GuideFrame") as MarginContainer
    if rect == null or rect.mouse_filter == Control.MOUSE_FILTER_STOP:
        _fail("mission guide frame not accessible")
        return
    guide_node.update_guide({
        "title": "Market Chowk",
        "objective": "Inspect the real incident near the north road",
        "has_target": true, "target": Vector3(0, 0, -8),
        "speaker": "Neighborhood Radio", "dialogue": "Use E near the evidence",
        "recovery_available": false
    }, Vector3.ZERO, Vector3.FORWARD)
    if not guide_node.objective_label.text.contains("Inspect") or not guide_node.waypoint_label.text.contains("WAYPOINT"):
        _fail("mission instructions were lost during layout")
        return
    if guide_node.reload_button.visible or guide_node.restart_button.visible:
        _fail("recovery actions appeared without gameplay permission")
        return
    guide_node.update_guide({
        "title": "Recovery", "objective": "Resume from a valid save",
        "recovery_available": true, "recovery_reason": "Checkpoint available"
    }, Vector3.ZERO, Vector3.FORWARD)
    if not guide_node.reload_button.visible or guide_node.reload_button.disabled:
        _fail("legitimate recovery action was not reachable")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_GAME_QA_MISSION_GUIDE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
