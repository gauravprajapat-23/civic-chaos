class_name CivicDistrictCampaign
extends RefCounted
## GAME-022: authoritative, read-only campaign completion and district results.
## No reward or metric mutations belong in this model.

const CHECKPOINT_VERSION: int = 1
const MISSION_IDS: Array[String] = [
    "market_footpath_intro",
    "market_wrong_way_live",
    "market_illegal_parking",
    "market_cleanup_chain"
]
const MISSION_TITLES: Array[String] = [
    "Footpath Blocked | Tutorial",
    "Wrong Way, Wrong Day",
    "Footpath First | Illegal Parking",
    "Market Clean-Up Chain"
]
const INCIDENT_KINDS: Array[String] = [
    "blocked_sidewalk", "wrong_way_driving", "illegal_parking", "market_litter"
]
const OUTCOME_PATTERNS: Array[String] = [
    "incident:%d:cleared", "wrong_way:%d:cleared",
    "parking:%d:reopened", "cleanup:%d:recovered"
]
const DIMENSIONS: Array[String] = ["safety", "efficiency", "trust", "cooperation"]

static func _whole(raw: Variant, minimum: int, maximum: int) -> bool:
    if not (raw is int or raw is float):
        return false
    var value: float = float(raw)
    return is_finite(value) and value == floorf(value) and value >= float(minimum) and value <= float(maximum)

static func _sources(civic: Variant, traffic: Variant, parking: Variant, cleanup: Variant) -> Array:
    return [civic, traffic, parking, cleanup]

## An unlock cannot be forged by setting "finished": the same civic snapshot
## must contain four resolved incidents, complete objectives, claimed rewards
## and each corresponding one-time audited score outcome.
static func can_unlock(civic: Variant, traffic: Variant, parking: Variant, cleanup: Variant) -> bool:
    var states: Array = _sources(civic, traffic, parking, cleanup)
    for item in states:
        if not (item is Dictionary) or not bool(item.get("finished", false)):
            return false
    var c: Dictionary = civic
    if not (c.get("incidents") is Dictionary) or not (c.get("missions") is Dictionary) or not (c.get("metrics") is Dictionary):
        return false
    var manager: CivicIncidentManager = CivicIncidentManager.from_json(JSON.stringify(c["incidents"]))
    var ledger := CivicMissionManager.new()
    if manager == null or not ledger.restore(c["missions"]):
        return false
    var metrics: Dictionary = c["metrics"]
    if not (metrics.get("scores") is Dictionary) or not (metrics.get("processed_events") is Dictionary):
        return false
    for dimension in DIMENSIONS:
        if not _whole(metrics["scores"].get(dimension), 0, 1000):
            return false
    var identities: Array = [c.get("incident_id"), traffic.get("incident_id"),
        parking.get("incident_id"), cleanup.get("incident_id")]
    var seen: Dictionary = {}
    for index in range(MISSION_IDS.size()):
        var id_value: Variant = identities[index]
        if not _whole(id_value, 1, 1000000000):
            return false
        var incident_id: int = int(id_value)
        if seen.has(incident_id) or not manager.incidents.has(incident_id):
            return false
        seen[incident_id] = true
        var incident: Dictionary = manager.incidents[incident_id]
        if str(incident.get("state", "")) != CivicIncidentManager.RESOLVED:
            return false
        # The wrong-way incident is named "wrong_way" in the live mission.
        if str(incident.get("kind", "")) != INCIDENT_KINDS[index]:
            return false
        var mission_id: String = MISSION_IDS[index]
        if not ledger.missions.has(mission_id) or not ledger.rewarded.has(mission_id):
            return false
        var mission: Dictionary = ledger.missions[mission_id]
        if str(mission.get("state", "")) != CivicMissionManager.COMPLETED:
            return false
        if not _whole(mission.get("reward"), 0, 10000):
            return false
        var progress: Dictionary = mission.get("progress", {})
        var objectives: Variant = mission.get("objectives")
        if not (objectives is Array) or objectives.is_empty():
            return false
        for objective in objectives:
            if not (objective is Dictionary):
                return false
            var key: String = str(objective.get("event", ""))
            if key.is_empty() or not _whole(objective.get("target"), 1, 100000):
                return false
            if not _whole(progress.get(key), int(objective["target"]), int(objective["target"])):
                return false
        var event_id: String = OUTCOME_PATTERNS[index] % incident_id
        if metrics["processed_events"].get(event_id) != true:
            return false
    return true

static func checkpoint(acknowledged: bool) -> Dictionary:
    return {"schema_version": CHECKPOINT_VERSION,
        "free_roam_unlocked": true, "finale_acknowledged": acknowledged}

static func checkpoint_valid(raw: Variant, civic: Variant, traffic: Variant,
        parking: Variant, cleanup: Variant) -> bool:
    if not (raw is Dictionary):
        return false
    var data: Dictionary = raw
    if not _whole(data.get("schema_version"), CHECKPOINT_VERSION, CHECKPOINT_VERSION):
        return false
    if not (data.get("free_roam_unlocked") is bool) or data["free_roam_unlocked"] != true:
        return false
    if not (data.get("finale_acknowledged") is bool):
        return false
    return can_unlock(civic, traffic, parking, cleanup)

static func _rank(score: int) -> String:
    if score >= 600:
        return "Outstanding"
    if score >= 540:
        return "Strong progress"
    if score >= 500:
        return "A better beginning"
    return "Room to improve"

static func scorecard(civic: Variant, traffic: Variant, parking: Variant,
        cleanup: Variant) -> Dictionary:
    if not can_unlock(civic, traffic, parking, cleanup):
        return {}
    var c: Dictionary = civic
    var scores: Dictionary = c["metrics"]["scores"]
    var mission_data: Dictionary = c["missions"]["missions"]
    var displayed_scores: Dictionary = {}
    var total: int = 0
    for dimension in DIMENSIONS:
        var score: int = int(scores[dimension])
        displayed_scores[dimension] = score
        total += score
    var reward_total: int = 0
    var mission_results: Array[Dictionary] = []
    for index in range(MISSION_IDS.size()):
        var id: String = MISSION_IDS[index]
        var reward: int = int(mission_data[id]["reward"])
        reward_total += reward
        mission_results.append({"id": id, "title": MISSION_TITLES[index],
            "status": "Completed", "reward": reward})
    var reputation: int = int(total / DIMENSIONS.size())
    return {
        "unlocked": true,
        "title": "MARKET CHOWK | DISTRICT RESTORED",
        "mission_count": mission_results.size(),
        "story_count": mission_results.size() - 1,
        "resolved_incidents": mission_results.size(),
        "missions": mission_results,
        "scores": displayed_scores,
        "reputation": reputation,
        "rating": _rank(reputation),
        "reward_total": reward_total
    }
