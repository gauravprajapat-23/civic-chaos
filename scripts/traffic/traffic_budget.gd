class_name CivicTrafficBudget
extends RefCounted
## Deterministic per-tick work limits. Never skip physical vehicle motion.
const DEFAULT_SENSOR_INTERVAL := 4
var sensor_interval_ticks: int = DEFAULT_SENSOR_INTERVAL
var maximum_agents: int = 20
var maximum_decisions_per_tick: int = 8
var _cursor: int = 0
var _last_tick: int = -1
var _sensor_cache: Dictionary = {}
var _timings_us: Array[int] = []
var _sensor_checks: Array[int] = []
const TIMING_WINDOW := 120

func configure(agent_limit: int, decisions_per_tick: int, sensor_interval: int = DEFAULT_SENSOR_INTERVAL) -> bool:
    if agent_limit < 1 or decisions_per_tick < 1 or sensor_interval < 1:
        return false
    maximum_agents = agent_limit
    maximum_decisions_per_tick = decisions_per_tick
    sensor_interval_ticks = sensor_interval
    return true

## A new traffic generation starts its own fixed-tick budget and telemetry.
## Do not call this on a rejected reconfiguration or an aborted restore:
## they must preserve the running generation's scheduler and observations.
func reset_runtime() -> void:
    _cursor = 0
    _last_tick = -1
    _sensor_cache.clear()
    _timings_us.clear()
    _sensor_checks.clear()

func select_decisions(tick: int, sorted_agent_ids: PackedInt32Array) -> PackedInt32Array:
    var selected := PackedInt32Array()
    if tick <= _last_tick:
        return selected
    _last_tick = tick
    if sorted_agent_ids.is_empty():
        _cursor = 0
        return selected
    var count: int = mini(maximum_decisions_per_tick, sorted_agent_ids.size())
    for index in range(count):
        selected.append(sorted_agent_ids[(_cursor + index) % sorted_agent_ids.size()])
    _cursor = (_cursor + count) % sorted_agent_ids.size()
    return selected

func sensor_due(tick: int, agent_id: int) -> bool:
    return tick >= 0 and agent_id >= 0 and posmod(tick + agent_id, sensor_interval_ticks) == 0

func cached_sensor(agent_id: int) -> Dictionary:
    return _sensor_cache.get(agent_id, {}).duplicate(true)

func update_sensor(agent_id: int, reading: Dictionary) -> void:
    if agent_id >= 0:
        _sensor_cache[agent_id] = reading.duplicate(true)

func prune(active_ids: PackedInt32Array) -> void:
    for id in _sensor_cache.keys():
        if not active_ids.has(int(id)):
            _sensor_cache.erase(id)

func record_duration_us(duration_us: int) -> void:
    if duration_us < 0:
        return
    _timings_us.append(duration_us)
    if _timings_us.size() > TIMING_WINDOW:
        _timings_us.remove_at(0)

## Count actual lead-sensor evaluations on every simulated traffic tick.
## These are observations, NOT skipped/approximated safety checks. Keep the
## telemetry bounded and separate from gameplay or decision scheduling.
func record_sensor_checks(count: int) -> void:
    if count < 0:
        return
    _sensor_checks.append(count)
    if _sensor_checks.size() > TIMING_WINDOW:
        _sensor_checks.remove_at(0)

func metrics() -> Dictionary:
    var total := 0
    var peak := 0
    for duration in _timings_us:
        total += duration
        peak = maxi(peak, duration)
    var sensor_total := 0
    var sensor_peak := 0
    for checks in _sensor_checks:
        sensor_total += checks
        sensor_peak = maxi(sensor_peak, checks)
    return {
        "sample_count": _timings_us.size(),
        "average_us": float(total) / float(maxi(_timings_us.size(), 1)),
        "peak_us": peak,
        "sensor_sample_count": _sensor_checks.size(),
        "sensor_checks_average": float(sensor_total) / float(maxi(_sensor_checks.size(), 1)),
        "sensor_checks_peak": sensor_peak,
        "agent_limit": maximum_agents,
        "decisions_per_tick": maximum_decisions_per_tick
    }
