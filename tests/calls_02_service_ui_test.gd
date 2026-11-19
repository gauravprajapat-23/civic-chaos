extends SceneTree
## CALLS-02: service dispatch requires a real accepted call and never
## triggers repeat requests or awards from panel state alone.
const Dispatch = preload("res://scripts/ui/free_roam_dispatch_board.gd")
const Response = preload("res://scripts/civic/call_service_response.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var board := Dispatch.new() as CivicFreeRoamDispatchBoard
    root.add_child(board)
    await process_frame
    board.set_available(true)
    var requested := [0]
    board.service_requested.connect(func() -> void: requested[0] += 1)
    var report: Dictionary = {
        "has_event": true, "call_id": 50101, "has_target": true,
        "target": Vector3(18, 0, -26), "title": "Fallen public sign",
        "location": "North Market Road", "service_type": "MAINTENANCE",
        "objective": "Inspect the sign", "seconds_left": 85
    }
    board.update_feed(report)
    if board.service_button.disabled == false or (
            Response.service_for("fallen_public_sign") != "MAINTENANCE"):
        _fail("service available before accepting a call or wrong service type")
        return
    if not board.accept_live_call(50101):
        _fail("valid live call could not be accepted")
        return
    if board.service_button.disabled or not board.service_button.visible:
        _fail("accepted call cannot request municipal assistance")
        return
    board.service_button.pressed.emit()
    if requested[0] != 1:
        _fail("service action did not emit its gameplay request")
        return
    board.service_requested_for(50101, "EN ROUTE")
    if not board.service_button.disabled or not board.service_status.text.contains("EN ROUTE"):
        _fail("duplicate service request not disabled")
        return
    board.service_requested_for(50101, "ON SCENE")
    if not board.service_status.text.contains("ON SCENE"):
        _fail("service arrival not reflected on dispatch board")
        return
    board.service_requested_for(50101, "SERVICE UNAVAILABLE")
    if board.service_button.disabled or not board.service_button.text.contains("RETRY"):
        _fail("unreachable responder did not unlock safe manual retry")
        return
    board.service_requested_for(50101, "EN ROUTE")
    if not board.service_button.disabled:
        _fail("retry failed to relock duplicate service request")
        return
    report["call_id"] = 50102
    board.update_feed(report)
    if board.accepted_live_call() or board.service_call_id != -1 or (
            not board.service_button.disabled):
        _fail("new live call inherited stale service")
        return
    if Response.service_for("civic_litter") != "SANITATION" or (
            Response.service_for("misplaced_safety_cone") != "ROAD SAFETY") or (
            Response.service_for("medical_emergency") != ""):
        _fail("service mapping authorizes unsupported emergencies")
        return
    board.queue_free()
    print("CIVIC_CHAOS_CALLS_02_SERVICE_UI_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
