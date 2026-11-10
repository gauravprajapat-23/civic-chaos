extends SceneTree
## PERF-01: validates observation math using synthetic fixtures only.
## No synthetic numbers may ever be labelled a real hardware baseline.
const Capture = preload("res://scripts/core/performance_capture.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var empty: CivicPerformanceCapture = Capture.new() as CivicPerformanceCapture
    var empty_report: Dictionary = empty.report()
    if empty_report["sample_count"] != 0 or empty_report["performance_target_verified"]:
        _fail("empty capture falsely claimed measured performance")
        return
    var cap: CivicPerformanceCapture = Capture.new() as CivicPerformanceCapture
    cap.configure({"device": "synthetic_test_only", "headless": true})
    for i in range(1, 21):
        if not cap.add_observation(_sample(float(i))):
            _fail("valid synthetic observation was rejected")
            return
    var report: Dictionary = cap.report()
    var frames: Dictionary = report["statistics"]["frame_interval_ms"]
    if report["sample_count"] != 20 or frames["count"] != 20:
        _fail("valid window lost observations")
        return
    if not is_equal_approx(float(frames["median"]), 10.0) or not is_equal_approx(float(frames["p95"]), 19.0):
        _fail("nearest-rank frame-time percentiles incorrect")
        return
    if not is_equal_approx(float(frames["mean"]), 10.5) or frames["min"] != 1.0 or frames["max"] != 20.0:
        _fail("frame-time average or min/max incorrect")
        return
    if report["gpu_time_ms"] != null or bool(report["gpu_timing_available"]) or bool(report["performance_target_verified"]):
        _fail("capture fabricated GPU evidence or passed release targets")
        return
    var previous: int = cap.count()
    var missing: Dictionary = _sample(15.0)
    missing.erase("physics_ms")
    if cap.add_observation(missing) or cap.count() != previous:
        _fail("incomplete performance record mutated the report")
        return
    for bad in [
        {"frame_interval_ms": 0.0}, {"frame_interval_ms": INF},
        {"frame_interval_ms": NAN}, {"pedestrian_update_us": -1.0},
        {"draw_calls": 0.5}, {"cars": -1}, {"walkers": "eight"}
    ]:
        var sample: Dictionary = _sample(15.0)
        sample.merge(bad, true)
        if cap.add_observation(sample) or cap.count() != previous:
            _fail("invalid sample bypassed fail-closed validation: " + str(bad))
            return
    var injected: Dictionary = _sample(10.0)
    if not cap.add_observation(injected):
        _fail("could not append a deep-copy test observation")
        return
    injected["cars"] = 1000
    if float(cap.report()["statistics"]["cars"]["max"]) != 8.0:
        _fail("external dictionary mutation changed recorded performance")
        return
    var snapshots: Dictionary = cap.report()
    snapshots["metadata"]["device"] = "mutated"
    if cap.report()["metadata"]["device"] != "synthetic_test_only":
        _fail("exposed metadata was not copied")
        return
    # The bounded sample window rejects overload rather than silently
    # retaining a misleading subset of a recording session.
    var limited: CivicPerformanceCapture = Capture.new() as CivicPerformanceCapture
    limited.configure({"device": "synthetic_test_only"})
    for i in range(Capture.MAX_SAMPLES):
        if not limited.add_observation(_sample(16.0)):
            _fail("capacity rejected a valid pre-limit observation")
            return
    if limited.add_observation(_sample(16.0)) or limited.count() != Capture.MAX_SAMPLES:
        _fail("bounded frame capture silently overflowed")
        return
    print("CIVIC_CHAOS_PERFORMANCE_CAPTURE_PASS")
    quit(0)

func _sample(frame_ms: float) -> Dictionary:
    return {
        "frame_interval_ms": frame_ms,
        "process_ms": 1.0,
        "physics_ms": 2.0,
        "pedestrian_update_us": 150.0,
        "traffic_update_us": 90.0,
        "draw_calls": 120,
        "static_memory_bytes": 65536,
        "cars": 8,
        "walkers": 8
    }

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
