extends SceneTree
## UX-02: compact HUD/incident modal bounds and action integrity.
const Hud = preload("res://scripts/ui/civic_status_hud.gd")
const Card = preload("res://scripts/ui/civic_incident_card.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for viewport in [
        Vector2(320, 568), Vector2(360, 740), Vector2(740, 360),
        Vector2(1280, 720), Vector2(1920, 1080)
    ]:
        var rectangle: Rect2 = Hud.layout_for(viewport)
        if rectangle.size.x <= 0.0 or rectangle.size.y <= 0.0:
            _fail("HUD rejected supported viewport " + str(viewport))
            return
        if rectangle.position.x < 0.0 or rectangle.position.y < 0.0 or rectangle.end.x > viewport.x or rectangle.end.y > viewport.y:
            _fail("HUD escaped viewport " + str(viewport))
            return
        var panel_size: Vector2 = Card.panel_bounds(viewport)
        if panel_size.x <= 0.0 or panel_size.y <= 0.0 or panel_size.x > viewport.x or panel_size.y > viewport.y:
            _fail("incident panel escaped viewport " + str(viewport))
            return
    if Hud.layout_for(Vector2.ZERO) != Rect2() or Card.panel_bounds(Vector2(INF, 720)) != Vector2.ZERO:
        _fail("invalid viewport geometry was accepted")
        return

    var stage := Node.new()
    root.add_child(stage)
    var hud := Hud.new() as CivicStatusHUD
    stage.add_child(hud)
    var card := Card.new() as CivicIncidentDetailCard
    stage.add_child(card)
    await process_frame
    if card.detail_scroll == null or card.detail_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        _fail("incident detail is not vertically scrollable without horizontal overflow")
        return
    if card.inspect_button.custom_minimum_size.y < 48.0 or card.report_button.custom_minimum_size.y < 48.0 or card.close_button.custom_minimum_size.y < 48.0:
        _fail("touch actions dropped below minimum comfortable target size")
        return
    var original := {"incidents": 2, "reputation": 530,
        "scores": {"safety": 515, "efficiency": 520, "trust": 535, "cooperation": 550},
        "feedback": "Inspect before reporting"}
    hud.render_state(original)
    if hud.current_state() != original or not hud.dimensions_label.text.contains("Safety 515"):
        _fail("layout changed authoritative civic score rendering")
        return
    var action_log: Array[String] = []
    card.action_selected.connect(func(action: String) -> void:
        action_log.append(action)
    )
    card.present({"title": "Long incident evidence", "location": "Market Chowk",
        "evidence": "A blocked crossing and delayed pedestrians.",
        "can_inspect": true, "can_report": false})
    if card.report_button.disabled != true or not card.is_open():
        _fail("modal offered an action without inspected evidence")
        return
    card.report_button.pressed.emit()
    if not action_log.is_empty():
        _fail("disabled civic report was emitted by the UI")
        return
    card.inspect_button.pressed.emit()
    if action_log != ["inspect"]:
        _fail("the evidence action was lost after responsive refactor")
        return
    card.close_button.pressed.emit()
    if card.is_open():
        _fail("modal could not be dismissed")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_UI_RESPONSIVE_CIVIC_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
