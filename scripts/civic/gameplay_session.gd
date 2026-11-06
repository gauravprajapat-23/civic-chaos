class_name CivicGameplaySession
extends Node
## GAME-006: first player-facing use of existing civic managers.
## Attach as PROCESS_MODE_PAUSABLE so paused gameplay does not advance cleanup.
## Intro scene: remove an *actual* sidewalk obstruction by inspection,
## valid reporting and authorized cleanup. No synthetic traffic queue claims.

signal feedback_changed(message: String)
signal incident_card_requested(data: Dictionary)

const Marker = preload("res://scripts/civic/incident_marker.gd")
const MISSION_ID: String = "market_footpath_intro"
const SERVICE_RESPONSE_TICKS: int = 45
const CLEANUP_TICKS: int = 90

var incidents := CivicIncidentManager.new()
var missions := CivicMissionManager.new()
var metrics := CivicCityMetrics.new()
var interactions := CivicInteractionService.new()

var marker: CivicIncidentMarker
var incident_id: int = -1
var tick: int = 0
var reported_tick: int = -1
var intervention_tick: int = -1
var cleanup_requested: bool = false
var finished: bool = false

var _world: Node3D
var _player: Node3D
var _hud: CivicStatusHUD
var feedback: String = "Find the orange obstruction near the north footpath."

func _init() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(world_root: Node3D, player_actor: Node3D, hud: CivicStatusHUD = null) -> bool:
    if world_root == null or player_actor == null or incident_id >= 0:
        return false
    if not interactions.configure(incidents, missions):
        return false
    var defined: bool = missions.register_mission({
        "id": MISSION_ID, "reward": 50, "objectives": [
            {"event": "obstruction_observed", "target": 1},
            {"event": "incident_reported", "target": 1},
            {"event": "path_cleared", "target": 1}
        ]
    })
    if not defined or not missions.start(MISSION_ID):
        return false
    var record: Dictionary = incidents.create_incident("blocked_sidewalk", 700, tick, "market_north_footpath")
    if not bool(record.get("ok", false)):
        return false
    incident_id = int(record["id"])
    _world = world_root
    _player = player_actor
    _hud = hud
    marker = Marker.new() as CivicIncidentMarker
    marker.name = "MarketFootpathObstruction"
    marker.position = Vector3(5.0, 0.21, -14.0)
    marker.incident_id = incident_id
    _world.add_child(marker)
    marker.activated.connect(_on_marker_activated)
    _publish()
    return true

## E / USE presents actual evidence and explicit safe actions.
## The UI is optional so tests and non-visual clients can use the same rules.
func _on_marker_activated(actor: Node) -> void:
    if not _can_interact(actor):
        _say("Move closer to the orange obstruction (within 3 metres).")
        return
    incident_card_requested.emit(incident_card_state())

func _can_interact(actor: Node) -> bool:
    if actor == null or actor != _player or finished or not is_instance_valid(marker):
        return false
    var distance_m: float = _player.global_position.distance_to(marker.global_position)
    return bool(interactions.inspect(incident_id, distance_m).get("ok", false))

func incident_card_state() -> Dictionary:
    var mission: Dictionary = missions.missions.get(MISSION_ID, {})
    var progress: Dictionary = mission.get("progress", {})
    var observed: bool = int(progress.get("obstruction_observed", 0)) > 0
    var reported: bool = reported_tick >= 0
    var phase: String = "Path reopened" if finished else "Municipal response in progress" if intervention_tick >= 0 else "Report accepted" if reported else "Evidence collected" if observed else "New civic incident"
    return {
        "title": "Market Chowk | Footpath Blocked",
        "location": "North footpath, near the junction",
        "evidence": "An orange crate blocks the walking route. The sidewalk should remain clear for pedestrians.",
        "phase": phase,
        "hint": "Inspect the obstruction first, then submit an accurate report. Municipal staff handle removal safely.",
        "can_inspect": not observed and not finished,
        "can_report": observed and not reported and not finished,
        "reported": reported,
        "finished": finished
    }

## Explicit action API shared by mouse/touch UI and old direct tests.
## Every action is validated again at the moment the player selects it.
func perform_incident_action(actor: Node, action: String) -> bool:
    if not _can_interact(actor):
        _say("Action unavailable: approach the footpath obstruction.")
        return false
    var distance_m: float = _player.global_position.distance_to(marker.global_position)
    var mission: Dictionary = missions.missions[MISSION_ID]
    var observed: bool = int(mission["progress"]["obstruction_observed"]) > 0
    if action == "inspect":
        if observed:
            _say("Evidence has already been collected.")
            return false
        if not missions.record_event(MISSION_ID, "obstruction_observed"):
            _say("Evidence could not be recorded.")
            return false
        _say("Evidence collected: pedestrian path is obstructed. You may now report it.")
        return true
    if action != "report":
        _say("Unknown civic action.")
        return false
    if not observed:
        _say("Inspect the obstruction before reporting it.")
        return false
    if reported_tick >= 0:
        _say("Report already submitted. Please allow the service team to respond.")
        return false
    var permissions := PackedStringArray(["report"])
    if not interactions.begin_action(0, incident_id, "report", distance_m, permissions):
        _say("Reporting is unavailable.")
        return false
    var result: Dictionary = interactions.confirm(0, tick, distance_m, permissions)
    if not bool(result.get("ok", false)):
        _say("Report failed: incident state or distance changed.")
        return false
    missions.record_event(MISSION_ID, "incident_reported")
    reported_tick = tick
    _say("Municipal report accepted. Watch the obstruction for a real response.")
    return true

## Compatibility with existing direct gameplay regressions: the same rules,
## with inspect first and report second, rather than bypassing validation.
func try_interact_at_marker(actor: Node) -> bool:
    var mission: Dictionary = missions.missions.get(MISSION_ID, {})
    var progress: Dictionary = mission.get("progress", {})
    var action: String = "inspect" if int(progress.get("obstruction_observed", 0)) == 0 else "report"
    return perform_incident_action(actor, action)

func _physics_process(_delta: float) -> void:
    if incident_id < 0 or finished:
        return
    tick += 1
    if reported_tick >= 0 and intervention_tick < 0 and tick - reported_tick >= SERVICE_RESPONSE_TICKS:
        if incidents.transition(incident_id, CivicIncidentManager.INTERVENTION, tick, "municipal_response_dispatched"):
            intervention_tick = tick
            _say("Municipal team responding to the blocked footpath.")
    if intervention_tick >= 0 and not cleanup_requested and tick - intervention_tick >= CLEANUP_TICKS:
        if is_instance_valid(marker):
            marker.queue_free()
            cleanup_requested = true
    if cleanup_requested and not is_instance_valid(marker):
        if incidents.transition(incident_id, CivicIncidentManager.RESOLVED, tick, "world_obstruction_removed"):
            missions.record_event(MISSION_ID, "path_cleared")
            # World collider has actually been removed. Idempotent event ID
            # prevents farming reputation by interacting repeatedly.
            metrics.apply_outcome("incident:%d:cleared" % incident_id, tick,
                {"efficiency": 25, "cooperation": 15}, "footpath_reopened")
            var reward_points: int = missions.claim_reward(MISSION_ID)
            finished = true
            _say("Footpath open again! Civic reward +%d." % reward_points)

func _say(message: String) -> void:
    feedback = message
    feedback_changed.emit(message)
    _publish()

func hud_state() -> Dictionary:
    return {
        "mission": (missions.missions.get(MISSION_ID, {}) as Dictionary).duplicate(true),
        "incidents": 0 if finished else 1,
        "reputation": metrics.reputation(),
        "scores": metrics.scores.duplicate(true),
        "feedback": feedback
    }

func _publish() -> void:
    if _hud == null or not is_instance_valid(_hud):
        return
    var state: Dictionary = _hud.current_state()
    state.merge(hud_state(), true)
    _hud.render_state(state)

## One versioned civic snapshot lives beside the existing v1 player save.
## Validation is pure and runs before any world or score changes.
func snapshot() -> Dictionary:
    return {
        "schema_version": 1,
        "tick": tick,
        "incident_id": incident_id,
        "reported_tick": reported_tick,
        "intervention_tick": intervention_tick,
        "cleanup_requested": cleanup_requested,
        "finished": finished,
        "feedback": feedback,
        "incidents": incidents.snapshot(),
        "missions": missions.snapshot(),
        "metrics": metrics.snapshot()
    }

## Godot JSON may decode whole-number values as floats. Convert only
## documented integer fields after confirming they are finite whole numbers.
## Never weaken the CivicCityMetrics.restore strict integer contract.
static func _integer_value(value: Variant) -> bool:
    if not (value is float or value is int):
        return false
    var number: float = float(value)
    return is_finite(number) and absf(number) <= 1000000000.0 and absf(number - roundf(number)) < 0.000001

static func _normalized_saved_state(data: Variant) -> Dictionary:
    if not (data is Dictionary):
        return {}
    var saved: Dictionary = (data as Dictionary).duplicate(true)
    for key in ["schema_version", "tick", "incident_id", "reported_tick", "intervention_tick"]:
        if not saved.has(key) or not _integer_value(saved[key]):
            return {}
        saved[key] = int(saved[key])
    if not (saved.get("metrics") is Dictionary):
        return {}
    var civic: Dictionary = saved["metrics"]
    if not _integer_value(civic.get("last_tick")) or not (civic.get("scores") is Dictionary):
        return {}
    civic["last_tick"] = int(civic["last_tick"])
    var scores: Dictionary = civic["scores"]
    for dimension in CivicCityMetrics.DIMENSIONS:
        if not _integer_value(scores.get(dimension)):
            return {}
        scores[dimension] = int(scores[dimension])
    return saved

func can_restore(data: Variant) -> bool:
    var saved: Dictionary = _normalized_saved_state(data)
    if saved.is_empty():
        return false
    if saved.get("schema_version") != 1:
        return false
    for field in ["tick", "incident_id", "reported_tick", "intervention_tick"]:
        if not (saved.get(field) is int):
            return false
    for field in ["cleanup_requested", "finished"]:
        if not (saved.get(field) is bool):
            return false
    if not (saved.get("feedback") is String):
        return false
    if not (saved.get("incidents") is Dictionary) or not (saved.get("missions") is Dictionary) or not (saved.get("metrics") is Dictionary):
        return false
    var saved_tick: int = saved["tick"]
    var report_at: int = saved["reported_tick"]
    var intervention_at: int = saved["intervention_tick"]
    if saved_tick < 0 or saved["incident_id"] < 1:
        return false
    if report_at < -1 or report_at > saved_tick or intervention_at < -1 or intervention_at > saved_tick:
        return false
    if intervention_at >= 0 and report_at < 0:
        return false
    if bool(saved["cleanup_requested"]) and intervention_at < 0:
        return false
    if bool(saved["finished"]) and not bool(saved["cleanup_requested"]):
        return false
    var incident_copy: CivicIncidentManager = CivicIncidentManager.from_json(JSON.stringify(saved["incidents"]))
    var mission_copy := CivicMissionManager.new()
    var metric_copy := CivicCityMetrics.new()
    if incident_copy == null or not mission_copy.restore(saved["missions"]) or not metric_copy.restore(saved["metrics"]):
        return false
    var id: int = saved["incident_id"]
    if not incident_copy.incidents.has(id) or not mission_copy.missions.has(MISSION_ID):
        return false
    if saved_tick < incident_copy.current_tick or saved_tick < metric_copy.last_tick:
        return false
    var incident: Dictionary = incident_copy.incidents[id]
    var mission: Dictionary = mission_copy.missions[MISSION_ID]
    var progress: Dictionary = mission.get("progress", {})
    if not progress.has("incident_reported") or not progress.has("obstruction_observed") or not progress.has("path_cleared"):
        return false
    if (report_at >= 0) != (int(progress["incident_reported"]) > 0):
        return false
    var incident_state: String = str(incident.get("state", ""))
    if report_at >= 0 and incident_state == CivicIncidentManager.ACTIVE:
        return false
    if intervention_at >= 0 and incident_state != CivicIncidentManager.INTERVENTION and incident_state != CivicIncidentManager.RESOLVED:
        return false
    if bool(saved["finished"]):
        if incident_state != CivicIncidentManager.RESOLVED or mission.get("state") != CivicMissionManager.COMPLETED or not mission_copy.rewarded.has(MISSION_ID):
            return false
        if int(progress["path_cleared"]) != 1:
            return false
    elif incident_state == CivicIncidentManager.RESOLVED:
        return false
    return true

func restore(data: Variant) -> bool:
    if not can_restore(data) or incident_id < 0:
        return false
    var saved: Dictionary = _normalized_saved_state(data)
    var replacement: CivicIncidentManager = CivicIncidentManager.from_json(JSON.stringify(saved["incidents"]))
    if replacement == null:
        return false
    var next_missions := CivicMissionManager.new()
    var next_metrics := CivicCityMetrics.new()
    if not next_missions.restore(saved["missions"]) or not next_metrics.restore(saved["metrics"]):
        return false
    incidents = replacement
    missions = next_missions
    metrics = next_metrics
    interactions.configure(incidents, missions)
    tick = saved["tick"]
    incident_id = saved["incident_id"]
    reported_tick = saved["reported_tick"]
    intervention_tick = saved["intervention_tick"]
    cleanup_requested = saved["cleanup_requested"]
    finished = saved["finished"]
    feedback = saved["feedback"]
    # The physical obstruction must match progress. Queued deletion is
    # resolved on the next frame; do not respawn a completed incident.
    if (cleanup_requested or finished) and is_instance_valid(marker):
        marker.queue_free()
    _publish()
    return true
