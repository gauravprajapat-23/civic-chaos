extends SceneTree
## Run after editor import:
## godot --headless --path . --script res://tests/determinism_test.gd

const ClockScript = preload("res://scripts/core/simulation_clock.gd")
const RandomScript = preload("res://scripts/core/seeded_random.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if not _test_clock():
        quit(1)
        return
    if not _test_rng():
        quit(1)
        return
    print("CIVIC_CHAOS_DETERMINISM_PASS")
    quit(0)

func _test_clock() -> bool:
    var a = ClockScript.new(20)
    var b = ClockScript.new(20)
    var log_a: Array[int] = []
    var log_b: Array[int] = []
    a.tick_started.connect(func(tick: int, _dt: float) -> void: log_a.append(tick))
    b.tick_started.connect(func(tick: int, _dt: float) -> void: log_b.append(tick))
    for dt in [0.01, 0.02, 0.03, 0.04, 0.05]:
        a.advance(dt)
        b.advance(dt)
    if log_a != log_b or a.tick_index != 3:
        push_error("Clock replay mismatch")
        return false
    a.paused = true
    if a.advance(1.0) != 0 or a.tick_index != 3:
        push_error("Paused clock advanced")
        return false
    a.reset()
    if a.tick_index != 0:
        push_error("Clock reset failed")
        return false
    return true

func _test_rng() -> bool:
    var a = RandomScript.new(42)
    var b = RandomScript.new(42)
    var seq_a: Array[float] = []
    var seq_b: Array[float] = []
    for i in range(12):
        seq_a.append(a.next_float(1001))
        seq_b.append(b.next_float(1001))
    if seq_a != seq_b:
        push_error("Seeded replay mismatch")
        return false
    var agent_two = RandomScript.new(42)
    agent_two.next_float(2002)
    if agent_two.next_float(1001) != seq_a[0]:
        push_error("Agent RNG streams not independent")
        return false
    a.reset()
    if a.next_float(1001) != seq_a[0]:
        push_error("RNG reset failed")
        return false
    return true
