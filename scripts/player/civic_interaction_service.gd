class_name CivicInteractionService
extends RefCounted
## Validated player-to-incident interactions; no implicit authority escalation.
const MAX_DISTANCE_M := 3.0

var incidents: CivicIncidentManager
var missions: CivicMissionManager
var pending: Dictionary = {}

func configure(manager: CivicIncidentManager, mission_manager: CivicMissionManager) -> bool:
    if manager == null or mission_manager == null:
        return false
    incidents = manager
    missions = mission_manager
    return true

func inspect(incident_id: int, distance_m: float) -> Dictionary:
    if incidents == null or not _in_range(distance_m) or not incidents.incidents.has(incident_id):
        return {"ok": false, "reason": "unavailable"}
    return {"ok": true, "incident": (incidents.incidents[incident_id] as Dictionary).duplicate(true)}

func begin_action(player_id: int, incident_id: int, action: String, distance_m: float, permissions: PackedStringArray) -> bool:
    if incidents == null or player_id < 0 or not _in_range(distance_m) or not incidents.incidents.has(incident_id):
        return false
    if not ["report", "resolve"].has(action) or not permissions.has(action):
        return false
    var state: String = incidents.incidents[incident_id]["state"]
    if state == CivicIncidentManager.RESOLVED:
        return false
    if action == "resolve" and state != CivicIncidentManager.INTERVENTION:
        return false
    pending[player_id] = {"incident_id": incident_id, "action": action}
    return true

func cancel(player_id: int) -> bool:
    if not pending.has(player_id):
        return false
    pending.erase(player_id)
    return true

func confirm(player_id: int, tick: int, distance_m: float, permissions: PackedStringArray) -> Dictionary:
    if incidents == null or not pending.has(player_id):
        return {"ok": false, "reason": "no_pending_action"}
    var request: Dictionary = pending[player_id]
    pending.erase(player_id)
    var action: String = request["action"]
    var id: int = int(request["incident_id"])
    if not _in_range(distance_m) or not permissions.has(action) or not incidents.incidents.has(id):
        return {"ok": false, "reason": "unauthorized_or_out_of_range"}
    var state: String = incidents.incidents[id]["state"]
    var next_state := ""
    if action == "report" and state == CivicIncidentManager.ACTIVE:
        next_state = CivicIncidentManager.ESCALATED
    elif action == "resolve" and state == CivicIncidentManager.INTERVENTION:
        next_state = CivicIncidentManager.RESOLVED
    else:
        return {"ok": false, "reason": "invalid_state"}
    if not incidents.transition(id, next_state, tick, "player_%s:%d" % [action, player_id]):
        return {"ok": false, "reason": "transition_denied"}
    return {"ok": true, "action": action, "incident_id": id}

func _in_range(distance_m: float) -> bool:
    return is_finite(distance_m) and distance_m >= 0.0 and distance_m <= MAX_DISTANCE_M
