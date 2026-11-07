class_name CivicNPCRoutines
extends RefCounted
## GAME-025-A draft: deterministic daily agenda for stable pedestrian IDs.
## Pure simulation data; physics, crossings, E/USE and civic scores remain
## exclusively owned by their existing systems. No wall-clock or global RNG.
const SCHEMA_VERSION: int = 1
const MAX_AGENTS: int = 128
const PHASE_TICKS: int = 300
const DAY_TICKS: int = 4 * PHASE_TICKS
const DEFAULT_SEED: int = 25025
const ROLES: Array[String] = ["commuter", "shopkeeper", "sanitation_worker", "resident"]
const PHASES: Array[String] = ["morning", "workday", "evening", "night"]

var _configured: bool = false
var _seed: int = DEFAULT_SEED
var _agent_count: int = 0
var _tick: int = 0

func configure(agent_count: int, seed_value: int = DEFAULT_SEED) -> bool:
    if _configured or agent_count < 0 or agent_count > MAX_AGENTS:
        return false
    if seed_value < 0 or seed_value > 1000000000:
        return false
    _agent_count = agent_count
    _seed = seed_value
    _tick = 0
    _configured = true
    return true

func advance_to(next_tick: int) -> bool:
    if not _configured or next_tick < _tick or next_tick > 1000000000:
        return false
    _tick = next_tick
    return true

static func phase_for_tick(at_tick: int) -> String:
    if at_tick < 0:
        return ""
    var phase_index: int = int(posmod(at_tick, DAY_TICKS) / PHASE_TICKS)
    return PHASES[phase_index]

static func role_for(agent_id: int, seed_value: int = DEFAULT_SEED) -> String:
    if agent_id < 0 or agent_id >= MAX_AGENTS or seed_value < 0 or seed_value > 1000000000:
        return ""
    var index: int = posmod(agent_id * 17 + seed_value, ROLES.size())
    return ROLES[index]

static func agenda_for(agent_id: int, at_tick: int, seed_value: int = DEFAULT_SEED) -> Dictionary:
    var role: String = role_for(agent_id, seed_value)
    var phase: String = phase_for_tick(at_tick)
    if role.is_empty() or phase.is_empty():
        return {}
    var action: String = ""
    var destination: String = ""
    var is_stationary: bool = false
    match role:
        "commuter":
            match phase:
                "morning":
                    action = "walk_to_work"
                    destination = "transit_stop"
                "workday":
                    action = "attend_work"
                    destination = "workplace"
                    is_stationary = true
                "evening":
                    action = "return_home"
                    destination = "residential_block"
                "night":
                    action = "rest"
                    destination = "residential_block"
                    is_stationary = true
        "shopkeeper":
            match phase:
                "morning":
                    action = "open_shop"
                    destination = "market_stall"
                "workday":
                    action = "serve_customers"
                    destination = "market_stall"
                    is_stationary = true
                "evening":
                    action = "close_shop"
                    destination = "market_stall"
                "night":
                    action = "return_home"
                    destination = "residential_block"
        "sanitation_worker":
            match phase:
                "morning":
                    action = "begin_route"
                    destination = "sanitation_depot"
                "workday":
                    action = "clean_street"
                    destination = "neighborhood_lane"
                "evening":
                    action = "finish_route"
                    destination = "sanitation_depot"
                "night":
                    action = "rest"
                    destination = "residential_block"
                    is_stationary = true
        "resident":
            match phase:
                "morning":
                    action = "morning_walk"
                    destination = "neighborhood_lane"
                "workday":
                    action = "buy_essentials"
                    destination = "market_stall"
                "evening":
                    action = "socialize"
                    destination = "community_square"
                    is_stationary = true
                "night":
                    action = "return_home"
                    destination = "residential_block"
    return {
        "id": agent_id, "role": role, "phase": phase,
        "activity": action, "destination": destination,
        "stationary": is_stationary
    }

func agent_state(agent_id: int) -> Dictionary:
    if not _configured or agent_id < 0 or agent_id >= _agent_count:
        return {}
    return agenda_for(agent_id, _tick, _seed)

func all_states() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not _configured:
        return result
    for id in range(_agent_count):
        result.append(agenda_for(id, _tick, _seed))
    return result

func checkpoint_state() -> Dictionary:
    if not _configured:
        return {}
    return {
        "schema_version": SCHEMA_VERSION,
        "seed": _seed,
        "agent_count": _agent_count,
        "tick": _tick,
        "agents": all_states()
    }

static func _whole(raw: Variant, minimum: int, maximum: int) -> bool:
    if not (raw is int or raw is float):
        return false
    var number: float = float(raw)
    return is_finite(number) and number == floorf(number) and number >= float(minimum) and number <= float(maximum)

func checkpoint_valid(raw: Variant) -> bool:
    if not _configured or not (raw is Dictionary):
        return false
    var data: Dictionary = raw
    if not _whole(data.get("schema_version"), SCHEMA_VERSION, SCHEMA_VERSION):
        return false
    if not _whole(data.get("seed"), _seed, _seed) or not _whole(data.get("agent_count"), _agent_count, _agent_count):
        return false
    if not _whole(data.get("tick"), 0, 1000000000) or not (data.get("agents") is Array):
        return false
    var records: Array = data["agents"]
    if records.size() != _agent_count:
        return false
    var at_tick: int = int(data["tick"])
    for id in range(_agent_count):
        if not (records[id] is Dictionary):
            return false
        var candidate: Dictionary = records[id]
        var expected: Dictionary = agenda_for(id, at_tick, _seed)
        if candidate.size() != expected.size():
            return false
        for key in expected.keys():
            if not candidate.has(key) or candidate[key] != expected[key]:
                return false
    return true

func restore_checkpoint(raw: Variant) -> bool:
    if not checkpoint_valid(raw):
        return false
    # The only mutable source of truth is logical time. Never restore
    # arbitrary role/position/destination fields from untrusted JSON.
    _tick = int(raw["tick"])
    return true

func current_tick() -> int:
    return _tick

func agent_count() -> int:
    return _agent_count
