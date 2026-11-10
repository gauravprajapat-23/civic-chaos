class_name CivicPerformanceCapture
extends RefCounted
## PERF-01. Bounded, read-only summary of actual Godot frame observations.
## No performance claim is made from synthetic fixture inputs.
const SCHEMA_VERSION: int = 1
const MAX_SAMPLES: int = 3600
const FIELDS: Array[String] = [
    "frame_interval_ms", "process_ms", "physics_ms",
    "pedestrian_update_us", "traffic_update_us",
    "draw_calls", "static_memory_bytes", "cars", "walkers"
]
var _samples: Array[Dictionary] = []
var _metadata: Dictionary = {}

func configure(metadata: Dictionary) -> void:
    _metadata = metadata.duplicate(true)
    _samples.clear()

func count() -> int:
    return _samples.size()

func add_observation(observation: Dictionary) -> bool:
    if _samples.size() >= MAX_SAMPLES:
        return false
    for field in FIELDS:
        if not observation.has(field):
            return false
        var value: Variant = observation[field]
        if not (value is int or value is float):
            return false
        var number: float = float(value)
        if not is_finite(number) or number < 0.0:
            return false
        if field in ["draw_calls", "static_memory_bytes", "cars", "walkers"] and number != floorf(number):
            return false
    if float(observation["frame_interval_ms"]) <= 0.0:
        return false
    _samples.append(observation.duplicate(true))
    return true

static func summarize_values(raw: Array) -> Dictionary:
    if raw.is_empty():
        return {"count": 0}
    var ordered: Array[float] = []
    for value in raw:
        if not (value is int or value is float):
            return {"count": 0}
        var number: float = float(value)
        if not is_finite(number) or number < 0.0:
            return {"count": 0}
        ordered.append(number)
    ordered.sort()
    var total: float = 0.0
    for value in ordered:
        total += value
    var n: int = ordered.size()
    return {
        "count": n,
        "min": ordered[0],
        "mean": total / float(n),
        "median": _nearest_rank(ordered, 0.50),
        "p95": _nearest_rank(ordered, 0.95),
        "max": ordered[n - 1]
    }

static func _nearest_rank(values: Array[float], percentile: float) -> float:
    var index: int = clampi(int(ceil(float(values.size()) * percentile)) - 1, 0, values.size() - 1)
    return values[index]

func report() -> Dictionary:
    var by_field: Dictionary = {}
    for field in FIELDS:
        var values: Array = []
        for observation in _samples:
            values.append(observation[field])
        by_field[field] = summarize_values(values)
    var frame: Dictionary = by_field["frame_interval_ms"]
    return {
        "schema_version": SCHEMA_VERSION,
        "sample_count": _samples.size(),
        "metadata": _metadata.duplicate(true),
        "statistics": by_field,
        "targets_ms": {"mobile_30fps": 1000.0 / 30.0, "desktop_60fps": 1000.0 / 60.0},
        "observed_median_fps": 1000.0 / float(frame["median"]) if _samples.size() > 0 and float(frame["median"]) > 0.0 else 0.0,
        # Godot's process/physics counters are CPU time, not GPU time.
        # This probe cannot determine the GPU bottleneck alone.
        "gpu_time_ms": null,
        "gpu_timing_available": false,
        "performance_target_verified": false
    }
