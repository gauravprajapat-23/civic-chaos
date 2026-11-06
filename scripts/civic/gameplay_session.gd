class_name CivicGameplaySession
extends Node
## GAME-006: first player-facing use of existing civic managers.
## Attach as PROCESS_MODE_PAUSABLE so paused gameplay does not advance cleanup.
## Intro scene: remove an *actual* sidewalk obstruction by inspection,
## valid reporting and authorized cleanup. No synthetic traffic queue claims.

signal feedback_changed(message: String)

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
    marker.activated.connect(try_interact_at_marker)
    _publish()
    return true

## Called by the in-world collider when the player looks at it and presses E.
## Tests also call this entry point directly to check distance/state contracts.
func try_interact_at_marker(actor: Node) -> bool:
    if actor == null or actor != _player or finished or not is_instance_valid(marker):
        return false
    var distance_m: float = _player.global_position.distance_to(marker.global_position)
    var inspection: Dictionary = interactions.inspect(incident_id, distance_m)
    if not bool(inspection.get("ok", false)):
        _say("Move closer to the obstruction (within 3 metres).")
        return false
    var mission: Dictionary = missions.missions[MISSION_ID]
    if int(mission["progress"]["obstruction_observed"]) == 0:
        missions.record_event(MISSION_ID, "obstruction_observed")
        _say("Footpath blocked! Evidence saved. Press E again to report.")
        return true
    if reported_tick >= 0:
        _say("Report already sent. Municipal help is on the way.")
        return false
    var permissions := PackedStringArray(["report"])
    if not interactions.begin_action(0, incident_id, "report", distance_m, permissions):
        _say("Report unavailable.")
        return false
    var result: Dictionary = interactions.confirm(0, tick, distance_m, permissions)
    if not bool(result.get("ok", false)):
        _say("Report failed: location or incident is no longer valid.")
        return false
    missions.record_event(MISSION_ID, "incident_reported")
    reported_tick = tick
    _say("Report accepted. Keep the path clear for municipal cleanup.")
    return true

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
        "feedback": feedback
    }

func _publish() -> void:
    if _hud == null or not is_instance_valid(_hud):
        return
    var state: Dictionary = _hud.current_state()
    state.merge(hud_state(), true)
    _hud.render_state(state)
