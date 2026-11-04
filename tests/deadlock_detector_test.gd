extends SceneTree

const Detector = preload("res://scripts/traffic/deadlock_detector.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var detector := Detector.new()
    assert(not detector.observe(1, -1, 0, "signal"))
    assert(detector.detect_cycles().is_empty())
    assert(detector.observe(1, 2, 0))
    assert(detector.observe(2, 3, 0))
    assert(detector.detect_cycles().is_empty())
    assert(detector.observe(3, 1, 0))
    assert(detector.detect_cycles().is_empty())
    assert(detector.advance_to(19))
    assert(detector.detect_cycles().is_empty())
    assert(detector.advance_to(20))
    var cycles := detector.detect_cycles()
    assert(cycles.size() == 1)
    assert(cycles[0] == PackedInt32Array([1, 2, 3]))
    detector.clear_wait(3)
    assert(detector.detect_cycles().is_empty())
    assert(detector.observe(3, 1, 21))
    assert(detector.advance_to(40))
    assert(detector.detect_cycles().is_empty())
    assert(detector.advance_to(41))
    assert(detector.detect_cycles().size() == 1)
    detector.clear_wait(1)
    assert(detector.detect_cycles().is_empty())
    print("CIVIC_CHAOS_DEADLOCK_PASS")
    quit(0)
