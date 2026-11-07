extends SceneTree
## PC/touch-sized evidence card and actual mission action validation.
## Does not claim a full visual human playtest.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Card = preload("res://scripts/ui/civic_incident_card.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    player.name = "PlayerRoot"
    player.position = Vector3(30.0, 0.21, -14.0)
    stage.add_child(player)
    var session: CivicGameplaySession = Session.new()
    stage.add_child(session)
    var card: CivicIncidentDetailCard = Card.new()
    stage.add_child(card)
    await process_frame
    if not session.configure(stage, player):
        _fail("Could not create civic incident scene")
        return
    if card.is_open():
        _fail("Incident card appeared without an interaction")
        return
    session.incident_card_requested.connect(card.present)
    card.action_selected.connect(func(action: String) -> void:
        session.perform_incident_action(player, action)
        card.render_card(session.incident_card_state())
    )
    # A distant actor cannot open or report a real-world incident.
    session.marker.interact(player)
    if card.is_open():
        _fail("Incident card opened despite out-of-range player")
        return
    player.position = Vector3(5.0, 0.21, -12.0)
    session.marker.interact(player)
    if not card.is_open():
        _fail("Nearby E/USE did not present evidence")
        return
    if card.inspect_button.disabled or not card.report_button.disabled:
        _fail("Report was available before evidence inspection")
        return
    if card.inspect_button.custom_minimum_size.y < 48.0 or card.report_button.custom_minimum_size.y < 48.0:
        _fail("Incident UI buttons are too small for touch")
        return
    # Disabled button must never bypass the incident service.
    card.report_button.pressed.emit()
    if session.reported_tick >= 0:
        _fail("Disabled report button filed a civic report")
        return
    card.inspect_button.pressed.emit()
    if not card.inspect_button.disabled or card.report_button.disabled:
        _fail("Evidence inspection did not unlock the report action")
        return
    var mission: Dictionary = session.missions.missions[Session.MISSION_ID]
    if int(mission["progress"]["obstruction_observed"]) != 1:
        _fail("Inspection was not recorded")
        return
    # Moving away while the card is open must invalidate the actual action.
    player.position = Vector3(30.0, 0.21, -14.0)
    card.report_button.pressed.emit()
    if session.reported_tick >= 0:
        _fail("Out-of-range report from an open card was accepted")
        return
    player.position = Vector3(5.0, 0.21, -12.0)
    card.report_button.pressed.emit()
    if session.reported_tick < 0 or not card.report_button.disabled:
        _fail("Valid report did not record and lock the action")
        return
    var first_report_tick: int = session.reported_tick
    card.report_button.pressed.emit()
    if session.reported_tick != first_report_tick:
        _fail("Duplicate report changed the original report state")
        return
    card.close_button.pressed.emit()
    if card.is_open():
        _fail("Close button failed to dismiss incident UI")
        return
    # Real-world response remains controlled by mission state, not the card.
    for frame in range(160):
        await physics_frame
    if not session.finished or is_instance_valid(session.marker):
        _fail("Reported world obstruction did not clear after service")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_GAMEPLAY_INCIDENT_CARD_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
