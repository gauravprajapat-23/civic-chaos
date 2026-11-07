extends SceneTree
## Reuse the established card without mutating its earlier report semantics.
const Card = preload("res://scripts/ui/civic_incident_card.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var panel := Card.new() as CivicIncidentDetailCard
    root.add_child(panel)
    await process_frame
    var actions: Array[String] = []
    panel.action_selected.connect(func(action: String) -> void:
        actions.append(action)
    )
    var data: Dictionary = {
        "title": "Illegal parking",
        "can_inspect": false,
        "can_report": true,
        "report_label": "Ask owner to relocate",
        "report_action": "request_owner"
    }
    panel.present(data)
    if panel.report_button.text != "Ask owner to relocate":
        _fail("owner-specific action label was lost")
        return
    panel.report_button.pressed.emit()
    if actions.size() != 1 or actions[0] != "request_owner":
        _fail("owner request emitted a generic civic report")
        return
    panel.render_card({"can_inspect": false, "can_report": true})
    panel.report_button.pressed.emit()
    if actions.size() != 2 or actions[1] != "report":
        _fail("existing report action was not preserved")
        return
    panel.dismiss()
    panel.queue_free()
    print("CIVIC_CHAOS_PARKING_OWNER_CARD_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
