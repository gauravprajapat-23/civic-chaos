class_name CivicWrongWayMission
extends RefCounted
## Scripted mission orchestration; all advances are explicit simulation ticks.
const MISSION_ID := "wrong_way_disaster"
const REQUIRED_QUEUE := 4
const RECOVERY_TICKS := 3

var incidents := CivicIncidentManager.new()
var missions := CivicMissionManager.new()
var scenario := CivicWrongWayScenario.new()
var interactions := CivicInteractionService.new()
var tick: int = 0
var reported: bool = false
var intervention_done: bool = false
var recovery_streak: int = 0

func setup() -> bool:
    var graph := CivicJunctionBuilder.make_test_graph()
    if not scenario.configure(graph, CivicIntersectionReservations.new(), incidents, 1, 99):
        return false
    if not interactions.configure(incidents, missions):
        return false
    if not missions.register_mission({"id": MISSION_ID, "reward": 100, "objectives": [
        {"event": "congestion_observed", "target": 1},
        {"event": "incident_reported", "target": 1},
        {"event": "marshal_intervened", "target": 1},
        {"event": "sustained_recovery", "target": 1}
    ]}):
        return false
    return missions.start(MISSION_ID)

func begin(offender_id: int) -> bool:
    return scenario.enter_violation(offender_id, tick)

func advance(demand: int) -> bool:
    tick += 1
    if not scenario.advance_to(tick, demand):
        return false
    if scenario.blocked and scenario.queue_count >= REQUIRED_QUEUE:
        missions.record_event(MISSION_ID, "congestion_observed")
    if intervention_done:
        if scenario.queue_count == 0:
            recovery_streak += 1
        else:
            recovery_streak = 0
        if recovery_streak >= RECOVERY_TICKS:
            if incidents.incidents[scenario.incident_id]["state"] == CivicIncidentManager.INTERVENTION:
                if scenario.resolve(tick):
                    missions.record_event(MISSION_ID, "sustained_recovery")
    return true

func report(player_id: int, distance_m: float) -> bool:
    if reported or not scenario.blocked or scenario.queue_count < REQUIRED_QUEUE:
        return false
    var permission := PackedStringArray(["report"])
    if not interactions.begin_action(player_id, scenario.incident_id, "report", distance_m, permission):
        return false
    var result := interactions.confirm(player_id, tick, distance_m, permission)
    if not result["ok"]:
        return false
    reported = true
    missions.record_event(MISSION_ID, "incident_reported")
    return true

func intervene() -> bool:
    if not reported or intervention_done:
        return false
    if not scenario.intervene(tick):
        return false
    intervention_done = true
    missions.record_event(MISSION_ID, "marshal_intervened")
    return true

func reward() -> int:
    return missions.claim_reward(MISSION_ID)

func status() -> Dictionary:
    return {"tick": tick, "queue": scenario.queue_count, "peak_queue": scenario.peak_queue, "recovery_streak": recovery_streak, "incident": incidents.incidents.get(scenario.incident_id, {}).duplicate(true), "mission": missions.missions.get(MISSION_ID, {}).duplicate(true)}
