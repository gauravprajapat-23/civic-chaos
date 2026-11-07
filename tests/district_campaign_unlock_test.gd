extends SceneTree
## GAME-022: only authoritative four-mission results grant Free Roam.
const Campaign = preload("res://scripts/civic/district_campaign.gd")
const Fixture = preload("res://tests/support/campaign_fixture.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world: Dictionary = Fixture.completed()
    if world.is_empty():
        _fail("test civic manager fixture did not complete four real objectives")
        return
    var civic: Dictionary = world["civic"]
    var wrong: Dictionary = world["wrong_way"]
    var parking: Dictionary = world["parking"]
    var cleanup: Dictionary = world["cleanup"]
    if not Campaign.can_unlock(civic, wrong, parking, cleanup):
        _fail("verified four-mission completion did not unlock Free Roam")
        return
    var report: Dictionary = Campaign.scorecard(civic, wrong, parking, cleanup)
    if report.get("mission_count") != 4 or report.get("story_count") != 3:
        _fail("district report lost tutorial or one of the story incidents")
        return
    if report.get("reward_total") != 315 or report.get("reputation") != 543 or report.get("rating") != "Strong progress":
        _fail("mission rewards or city reputation were fabricated")
        return
    var scores: Dictionary = report.get("scores", {})
    if scores.get("safety") != 535 or scores.get("efficiency") != 545 or scores.get("trust") != 535 or scores.get("cooperation") != 560:
        _fail("scorecard does not reflect civic manager outcome history")
        return
    if report != Campaign.scorecard(civic, wrong, parking, cleanup):
        _fail("viewing results twice changed score or reward totals")
        return
    var snapshot: Variant = JSON.parse_string(JSON.stringify(Campaign.checkpoint(false)))
    if not Campaign.checkpoint_valid(snapshot, civic, wrong, parking, cleanup):
        _fail("legitimate locked-unacknowledged finale failed JSON round trip")
        return
    if not Campaign.checkpoint_valid(Campaign.checkpoint(true), civic, wrong, parking, cleanup):
        _fail("acknowledged free roam checkpoint was rejected")
        return
    var invalid: Dictionary = (snapshot as Dictionary).duplicate(true)
    invalid["free_roam_unlocked"] = false
    if Campaign.checkpoint_valid(invalid, civic, wrong, parking, cleanup):
        _fail("wrong free roam flag accepted")
        return
    invalid = (snapshot as Dictionary).duplicate(true)
    invalid["free_roam_unlocked"] = 1
    if Campaign.checkpoint_valid(invalid, civic, wrong, parking, cleanup):
        _fail("numeric forged Free Roam flag accepted as boolean")
        return
    invalid = (snapshot as Dictionary).duplicate(true)
    invalid["schema_version"] = 19
    if Campaign.checkpoint_valid(invalid, civic, wrong, parking, cleanup):
        _fail("unsupported finale version accepted")
        return
    invalid = (snapshot as Dictionary).duplicate(true)
    invalid["finale_acknowledged"] = "yes"
    if Campaign.checkpoint_valid(invalid, civic, wrong, parking, cleanup):
        _fail("nonboolean acknowledgement accepted")
        return

    var forged_cleanup: Dictionary = cleanup.duplicate(true)
    forged_cleanup["finished"] = false
    if Campaign.can_unlock(civic, wrong, parking, forged_cleanup) or not Campaign.scorecard(civic, wrong, parking, forged_cleanup).is_empty():
        _fail("unfinished market cleanup unlocked district")
        return
    var forged: Dictionary = civic.duplicate(true)
    forged["missions"]["rewarded"].erase(Campaign.MISSION_IDS[2])
    if Campaign.can_unlock(forged, wrong, parking, cleanup):
        _fail("unclaimed parking reward unlocked district")
        return
    forged = civic.duplicate(true)
    forged["missions"]["missions"][Campaign.MISSION_IDS[1]]["progress"]["verified"] = 0
    if Campaign.can_unlock(forged, wrong, parking, cleanup):
        _fail("uncompleted wrong-way objective unlocked district")
        return
    forged = civic.duplicate(true)
    forged["incidents"]["incidents"][2]["state"] = CivicIncidentManager.ACTIVE
    if Campaign.can_unlock(forged, wrong, parking, cleanup):
        _fail("unresolved parking incident unlocked district")
        return
    forged = civic.duplicate(true)
    forged["metrics"]["processed_events"].erase(Campaign.OUTCOME_PATTERNS[3] % cleanup["incident_id"])
    if Campaign.can_unlock(forged, wrong, parking, cleanup):
        _fail("missing audited sanitation recovery unlocked district")
        return
    forged = civic.duplicate(true)
    forged["metrics"]["scores"]["safety"] = 3000
    if Campaign.can_unlock(forged, wrong, parking, cleanup):
        _fail("out-of-bounds city reputation was accepted")
        return
    print("CIVIC_CHAOS_DISTRICT_CAMPAIGN_UNLOCK_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
