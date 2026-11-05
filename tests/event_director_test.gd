extends SceneTree

const Director = preload("res://scripts/civic/event_director.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var a := Director.new()
    var b := Director.new()
    assert(a.configure(1234, 4, 2))
    assert(b.configure(1234, 4, 2))
    var event_a := {"id": "wrong_way", "cost": 3, "cooldown": 5, "duration": 2, "tags": ["junction"], "conditions": {"congestion": 2}}
    var event_b := {"id": "roadwork", "cost": 3, "cooldown": 5, "duration": 2, "tags": ["junction"], "conditions": {"congestion": 2}}
    for director in [a, b]:
        assert(director.register_event(event_a))
        assert(director.register_event(event_b))
        assert(not director.register_event(event_a))
    for tick in range(10):
        var first := a.advance_to(tick, {"congestion": 2})
        var second := b.advance_to(tick, {"congestion": 2})
        assert(first == second)
        assert(a.snapshot() == b.snapshot())
        assert(a.active.size() <= 1)
        assert(a.budget >= 1)
    assert(not a.advance_to(2, {"congestion": 2})["ok"])
    var gated := Director.new()
    assert(gated.configure(7, 2, 1))
    assert(gated.register_event({"id": "expensive", "cost": 3, "cooldown": 1, "duration": 2, "tags": [], "conditions": {}}))
    assert(gated.advance_to(0, {})["started"] == "")
    print("CIVIC_CHAOS_EVENT_DIRECTOR_PASS")
    quit(0)
