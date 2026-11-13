extends SceneTree
## PROG-01: rankings are display-only and milestone progress is receipt-backed.
const Progression = preload("res://scripts/civic/volunteer_progression.gd")
const HUD = preload("res://scripts/ui/civic_status_hud.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if Progression.rank_for(500) != "New Volunteer" or Progression.rank_for(540) != "Neighborhood Helper":
        _fail("wrong entry rank thresholds")
        return
    if Progression.rank_for(600) != "Trusted Volunteer" or Progression.rank_for(700) != "Community Champion":
        _fail("wrong upper rank thresholds")
        return
    var receipts: Dictionary = {}
    var empty: Dictionary = Progression.overview(540, 0, receipts)
    if empty.get("next_goal") != 3 or empty.get("remaining") != 3:
        _fail("first civic milestone was not offered")
        return
    for index in range(1, 11):
        receipts["free_roam:%d:resolved" % index] = true
    receipts["parking:5:reopened"] = true
    var goals: Dictionary = Progression.overview(620, 10, receipts)
    if goals.get("rank") != "Trusted Volunteer" or goals.get("next_goal") != 25:
        _fail("rank or third milestone was not computed from receipts")
        return
    if goals.get("remaining") != 15 or goals["badges"].size() != 2:
        _fail("reward badge list was not milestone-based")
        return
    var replay: Variant = JSON.parse_string(JSON.stringify(receipts))
    if Progression.overview(620, 10, replay) != goals:
        _fail("JSON replay changed progression state")
        return
    if not Progression.overview(620, 11, receipts).is_empty():
        _fail("forged extra resolved count elevated progression")
        return
    receipts["free_roam:11:resolved"] = false
    if not Progression.overview(620, 11, receipts).is_empty():
        _fail("unverified completion receipt elevated progression")
        return
    if not Progression.overview(1001, 0, {}).is_empty():
        _fail("out-of-range reputation was accepted")
        return
    var hud := HUD.new() as CivicStatusHUD
    root.add_child(hud)
    await process_frame
    hud.render_state({"free_roam_resolved": 10, "free_roam_expired": 0,
        "volunteer_progress": goals, "reputation": 620})
    if not hud.roam_label.text.contains("Trusted Volunteer"):
        _fail("volunteer rank is missing from Free Roam HUD")
        return
    if not hud.roam_label.text.contains("10/25"):
        _fail("next badge goal is not visible")
        return
    hud.queue_free()
    print("CIVIC_CHAOS_VOLUNTEER_PROGRESSION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
