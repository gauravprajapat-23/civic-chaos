extends SceneTree
## GAME-021: per-target action dispatch must never become a generic report.
const Card = preload("res://scripts/ui/civic_incident_card.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var panel := Card.new() as CivicIncidentDetailCard
    root.add_child(panel)
    await process_frame
    var received: Array[String] = []
    panel.action_selected.connect(func(action: String) -> void:
        received.append(action)
    )
    var variants: Array[Dictionary] = [
        {"report_action": "collect_litter", "report_label": "Collect wrapper"},
        {"report_action": "deposit_litter", "report_label": "Place wrapper in bin"},
        {"report_action": "request_service", "report_label": "Request sanitation"}
    ]
    for entry in variants:
        panel.present({"title": "Market Clean-Up Chain",
            "can_inspect": false, "can_report": true,
            "report_action": entry["report_action"],
            "report_label": entry["report_label"]})
        if panel.report_button.disabled or panel.report_button.text != entry["report_label"]:
            _fail("market card lost the specific action label")
            return
        panel.report_button.pressed.emit()
        if received.is_empty() or received[received.size() - 1] != entry["report_action"]:
            _fail("market action was dispatched incorrectly")
            return
    panel.render_card({"can_inspect": false, "can_report": true,
        "report_action": "invented_unsafe_action"})
    panel.report_button.pressed.emit()
    if received.size() != 4 or received[3] != "report":
        _fail("unknown civic card action bypassed safe report default")
        return
    panel.render_card({"can_inspect": false, "can_report": false,
        "report_action": "deposit_litter"})
    var previous_count: int = received.size()
    panel.report_button.pressed.emit()
    if received.size() != previous_count:
        _fail("disabled bin action was still dispatched")
        return
    panel.dismiss()
    panel.queue_free()
    print("CIVIC_CHAOS_MARKET_CLEANUP_CARD_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
