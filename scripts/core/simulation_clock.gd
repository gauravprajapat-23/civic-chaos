class_name SimulationClock
extends RefCounted
## Deterministic fixed-step logical clock. Not tied to render FPS.
## Caller supplies delta and dispatches all simulation systems on each tick.

signal tick_started(tick_index: int, fixed_delta: float)
signal tick_finished(tick_index: int)

const DEFAULT_HZ: int = 20
const MAX_TICKS_PER_FRAME: int = 8
const EPSILON: float = 0.000000001

var tick_index: int = 0
var fixed_delta: float = 1.0 / float(DEFAULT_HZ)
var paused: bool = false
var _accumulator: float = 0.0

func _init(ticks_per_second: int = DEFAULT_HZ) -> void:
    assert(ticks_per_second > 0, "Simulation frequency must be positive")
    fixed_delta = 1.0 / float(maxi(1, ticks_per_second))

func advance(delta: float) -> int:
    if paused or delta <= 0.0:
        return 0
    _accumulator += delta
    var count: int = 0
    while _accumulator + EPSILON >= fixed_delta and count < MAX_TICKS_PER_FRAME:
        _accumulator -= fixed_delta
        if absf(_accumulator) < EPSILON:
            _accumulator = 0.0
        step_once()
        count += 1
    return count

func step_once() -> void:
    tick_index += 1
    tick_started.emit(tick_index, fixed_delta)
    tick_finished.emit(tick_index)

func reset() -> void:
    tick_index = 0
    _accumulator = 0.0
    paused = false

func interpolation_alpha() -> float:
    return clampf(_accumulator / fixed_delta, 0.0, 1.0)

func get_elapsed_seconds() -> float:
    return float(tick_index) * fixed_delta

## GAME-019: fixed-step checkpoint. The accumulator is included so the
## next physics frame does not artificially advance/skip a simulation tick.
func snapshot() -> Dictionary:
    return {
        "schema_version": 1,
        "tick_index": tick_index,
        "fixed_delta": fixed_delta,
        "accumulator": _accumulator,
        "paused": paused
    }

func can_restore(data: Variant) -> bool:
    if not (data is Dictionary):
        return false
    if not (data.get("schema_version") is int or data.get("schema_version") is float):
        return false
    if float(data["schema_version"]) != 1.0:
        return false
    for field in ["tick_index", "fixed_delta", "accumulator"]:
        if not (data.get(field) is int or data.get(field) is float):
            return false
        if not is_finite(float(data[field])):
            return false
    var candidate_tick: float = float(data["tick_index"])
    if candidate_tick != floorf(candidate_tick) or candidate_tick < 0.0 or candidate_tick > 1000000000.0:
        return false
    var candidate_fixed: float = float(data["fixed_delta"])
    if absf(candidate_fixed - fixed_delta) > 0.0000001:
        return false
    var candidate_accum: float = float(data["accumulator"])
    if candidate_accum < -EPSILON or candidate_accum >= fixed_delta + EPSILON:
        return false
    return data.get("paused") is bool

func restore(data: Variant) -> bool:
    if not can_restore(data):
        return false
    tick_index = int(data["tick_index"])
    _accumulator = clampf(float(data["accumulator"]), 0.0, fixed_delta - EPSILON)
    paused = bool(data["paused"])
    return true
