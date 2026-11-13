class_name CivicCampaignFixture
extends RefCounted
## Deterministic GAME-022 completion fixture using actual manager contracts.
const Campaign = preload("res://scripts/civic/district_campaign.gd")

static func completed() -> Dictionary:
    var incidents := CivicIncidentManager.new()
    var missions := CivicMissionManager.new()
    var metrics := CivicCityMetrics.new()
    var identities: Array[int] = []
    var rewards := [50, 100, 75, 90]
    var outcomes: Array[Dictionary] = [
        {"efficiency": 25, "cooperation": 15},
        {"safety": 20, "efficiency": 10},
        {"safety": 15, "trust": 20, "cooperation": 20},
        {"cooperation": 25, "trust": 15, "efficiency": 10}
    ]
    for index in range(Campaign.MISSION_IDS.size()):
        var tick: int = index * 20 + 2
        var created: Dictionary = incidents.create_incident(
            Campaign.INCIDENT_KINDS[index], 700 + index, tick - 2,
            "market_case_%d" % index)
        if not bool(created.get("ok", false)):
            return {}
        var id: int = int(created["id"])
        identities.append(id)
        if not incidents.transition(id, CivicIncidentManager.INTERVENTION, tick - 1, "world_responded"):
            return {}
        if not incidents.transition(id, CivicIncidentManager.RESOLVED, tick, "physical_recovery_verified"):
            return {}
        if not missions.register_mission({"id": Campaign.MISSION_IDS[index],
            "reward": rewards[index], "objectives": [{"event": "verified", "target": 1}]}):
            return {}
        if not missions.start(Campaign.MISSION_IDS[index]):
            return {}
        if not missions.record_event(Campaign.MISSION_IDS[index], "verified"):
            return {}
        if missions.claim_reward(Campaign.MISSION_IDS[index]) != rewards[index]:
            return {}
        if not metrics.apply_outcome(Campaign.OUTCOME_PATTERNS[index] % id, tick,
                outcomes[index], "verified_city_recovery"):
            return {}
    return {
        "civic": {
            "finished": true, "incident_id": identities[0],
            "incidents": incidents.snapshot(),
            "missions": missions.snapshot(),
            "metrics": metrics.snapshot()
        },
        "wrong_way": {"finished": true, "incident_id": identities[1]},
        "parking": {"finished": true, "incident_id": identities[2]},
        "cleanup": {"finished": true, "incident_id": identities[3]}
    }
