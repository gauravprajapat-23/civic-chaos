class_name CivicNpcDecisionStability
extends RefCounted
## Optional utility-AI hysteresis, one instance per NPC.
## NOT connected to gameplay while the AUD-001 Godot gate is pending.
## The raw CivicNpcUtilityEngine remains the scoring/safety authority.
##
## The current action gets inertia near a tie; unsafe actions are never held.
## All time is measured in deterministic simulation ticks, not wall time.

const Utility = preload("res://scripts/npc/npc_utility_engine.gd")
const SCHEMA_VERSION: int = 1
const DEFAULT_HOLD_TICKS: int = 6
const DEFAULT_SWITCH_MARGIN: float = 0.08

var minimum_hold_ticks: int = DEFAULT_HOLD_TICKS
var switch_margin: float = DEFAULT_SWITCH_MARGIN

var _npc_id: int = -1
var _current_action: String = ""
var _last_tick: int = -1
var _last_switch_tick: int = -1

func reset() -> void:
    _npc_id = -1
    _current_action = ""
    _last_tick = -1
    _last_switch_tick = -1

## Inputs are pure snapshots; never store references to the live blackboard.
## In particular, a previously legal "cross_legally" must be dropped in the
## very same tick if the light turns red or a collision blocks the crossing.
func decide(personality: CivicNpcPersonality, board: CivicNpcBlackboard, seed: int = 0) -> Dictionary:
    if board == null or personality == null or board.npc_id < 0:
        return _invalid("invalid_context")
    if _npc_id >= 0 and _npc_id != board.npc_id:
        return _invalid("different_npc_requires_reset")
    if board.tick_index < 0 or board.tick_index < _last_tick:
        return _invalid("stale_simulation_tick")
    if minimum_hold_ticks < 0 or minimum_hold_ticks > 1000 or not is_finite(switch_margin) or switch_margin < 0.0 or switch_margin > 1.0:
        return _invalid("invalid_hysteresis_settings")
    if not _observations_valid(board.observations):
        return _invalid("invalid_observations")

    var raw: Dictionary = Utility.choose(personality, board, seed)
    if not bool(raw.get("ok", false)):
        return _invalid("invalid_utility_scores")
    var scores: Dictionary = raw.get("scores", {})
    var candidate: String = str(raw.get("action", "wait"))
    if not scores.has(candidate):
        return _invalid("utility_action_missing")

    var previous: String = _current_action
    var selected: String = candidate
    var reason: String = "initial"
    if not previous.is_empty():
        if not scores.has(previous):
            # This is a hard safety interrupt. Never preserve an unavailable
            # action, regardless of inertia, cooldown or simulation tick.
            reason = "safety_override"
        elif candidate == previous:
            reason = "maintained"
        else:
            var advantage: float = float(scores[candidate]) - float(scores[previous])
            if advantage <= switch_margin + 0.000001:
                selected = previous
                reason = "hysteresis"
            elif board.tick_index - _last_switch_tick < minimum_hold_ticks:
                selected = previous
                reason = "minimum_hold"
            else:
                reason = "stronger_action"

    if _npc_id < 0:
        _npc_id = board.npc_id
    if selected != previous:
        _last_switch_tick = board.tick_index
    _current_action = selected
    _last_tick = board.tick_index
    return {
        "ok": true, "action": selected, "reason": reason,
        "changed": selected != previous, "tick": _last_tick,
        "score": float(scores[selected]), "scores": scores
    }

func snapshot() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "npc_id": _npc_id,
        "current_action": _current_action,
        "last_tick": _last_tick,
        "last_switch_tick": _last_switch_tick
    }

## A policy snapshot does not change the game's persisted save schema.
## It is an opt-in per-agent checkpoint for later GAME-025 integration.
func can_restore(raw: Variant) -> bool:
    if not (raw is Dictionary):
        return false
    var data: Dictionary = raw
    for key in ["schema_version", "npc_id", "last_tick", "last_switch_tick"]:
        if not (data.get(key) is int):
            return false
    if int(data["schema_version"]) != SCHEMA_VERSION:
        return false
    if not (data.get("current_action") is String):
        return false
    var action: String = data["current_action"]
    if not action.is_empty() and not Utility.ACTIONS.has(action):
        return false
    var npc: int = data["npc_id"]
    var tick: int = data["last_tick"]
    var switched: int = data["last_switch_tick"]
    if npc < -1 or tick < -1 or switched < -1 or switched > tick:
        return false
    if npc == -1:
        return tick == -1 and switched == -1 and action.is_empty()
    return tick >= 0 and switched >= 0 and not action.is_empty()

func restore(raw: Variant) -> bool:
    if not can_restore(raw):
        return false
    var data: Dictionary = raw
    _npc_id = int(data["npc_id"])
    _current_action = str(data["current_action"])
    _last_tick = int(data["last_tick"])
    _last_switch_tick = int(data["last_switch_tick"])
    return true

static func _observations_valid(obs: Dictionary) -> bool:
    for key in ["urgency", "social_influence"]:
        if not obs.has(key):
            continue
        var value: Variant = obs[key]
        if not (value is float or value is int):
            return false
        var number: float = float(value)
        if not is_finite(number):
            return false
        if key == "urgency" and (number < 0.0 or number > 1.0):
            return false
        if key == "social_influence" and (number < -1.0 or number > 1.0):
            return false
    for key in ["pedestrian_green", "crossing_clear", "person_needs_help", "safe_to_help"]:
        if obs.has(key) and not (obs[key] is bool):
            return false
    return true

static func _invalid(why: String) -> Dictionary:
    return {"ok": false, "action": "wait", "reason": why, "changed": false}
