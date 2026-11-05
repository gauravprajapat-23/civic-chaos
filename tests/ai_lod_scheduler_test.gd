extends SceneTree

const Scheduler = preload("res://scripts/npc/ai_lod_scheduler.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var s := Scheduler.new()
    assert(s.register_agent(3, 100.0))
    assert(s.register_agent(1, 10.0))
    assert(s.register_agent(2, 50.0))
    assert(s.advance_to(0) == PackedInt32Array([1, 2, 3]))
    for tick in range(1, 40):
        s.advance_to(tick)
    assert(s.snapshot(1)["decision_count"] == 40)
    assert(s.snapshot(2)["decision_count"] == 10)
    assert(s.snapshot(3)["decision_count"] == 2)
    assert(s.set_distance(3, 10.0))
    s.advance_to(40)
    assert(s.snapshot(3)["decision_count"] == 3)
    assert(s.advance_to(40).is_empty())
    assert(s.advance_to(39).is_empty())
    s.unregister_agent(2)
    assert(s.snapshot(2).is_empty())
    print("CIVIC_CHAOS_AI_LOD_PASS")
    quit(0)
