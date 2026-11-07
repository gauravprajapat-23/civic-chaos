extends SceneTree
## GAME-023: the existing action card cannot turn Free Roam actions into reports.
const Card = preload("res://scripts/ui/civic_incident_card.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var panel := Card.new() as CivicIncidentDetailCard
    root.add_child(panel)
    await process_frame
    var selected: Array[String] = []
    panel.action_selected.connect(func(action: String) -> void:
        selected.append(action)
    )
    for action in ["collect_sign", "place_sign", "collect_litter", "deposit_litter", "collect_cone", "store_cone"]:
        panel.present({"title": "Free Roam",
            "can_inspect": false, "can_report": true,
            "report_action": action, "report_label": action})
        if panel.report_button.disabled or panel.report_button.get_meta("report_action") != action:
            _fail("Free Roam card lost safe typed action dispatch")
            return
        panel.report_button.pressed.emit()
        if selected.is_empty() or selected[selected.size() - 1] != action:
            _fail("Free Roam card emitted a generic report instead of physical action")
            return
    panel.render_card({"can_report": false, "report_action": "place_sign"})
    var before: int = selected.size()
    panel.report_button.pressed.emit()
    if selected.size() != before:
        _fail("disabled placement button remained actionable")
        return
    panel.dismiss()
    panel.queue_free()
    print("CIVIC_CHAOS_FREE_ROAM_CARD_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
