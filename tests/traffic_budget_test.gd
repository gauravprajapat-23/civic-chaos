extends SceneTree
const Budget = preload("res://scripts/traffic/traffic_budget.gd")

func _initialize() -> void:
    var budget := Budget.new()
    if budget.configure(0, 4):
        _fail("traffic budget accepted a zero-agent limit")
        return
    if not budget.configure(12, 2, 4):
        _fail("traffic budget rejected valid limits")
        return
    var ids := PackedInt32Array([10, 20, 30, 40, 50])
    if budget.select_decisions(1, ids) != PackedInt32Array([10, 20]):
        _fail("first round robin selection incorrect")
        return
    if budget.select_decisions(2, ids) != PackedInt32Array([30, 40]):
        _fail("second round robin selection incorrect")
        return
    if budget.select_decisions(3, ids) != PackedInt32Array([50, 10]):
        _fail("round robin cursor failed to wrap")
        return
    if not budget.select_decisions(3, ids).is_empty():
        _fail("same simulation tick repeated traffic budget decisions")
        return
    if not budget.sensor_due(4, 0):
        _fail("sensor budget omitted a due observation")
        return
    if budget.sensor_due(5, 0):
        _fail("sensor budget ran on an unscheduled tick")
        return
    budget.update_sensor(10, {"gap": 3.0})
    if budget.cached_sensor(10).get("gap") != 3.0:
        _fail("traffic sensor cache lost a stored observation")
        return
    budget.prune(PackedInt32Array([20]))
    if not budget.cached_sensor(10).is_empty():
        _fail("traffic sensor cache was not pruned")
        return
    for i in range(130):
        budget.record_duration_us(i)
    var metrics := budget.metrics()
    if metrics["sample_count"] != 120:
        _fail("traffic performance history exceeded bounded sample window")
        return
    if metrics["peak_us"] != 129:
        _fail("traffic peak time metric incorrect")
        return
    if metrics["average_us"] <= 60.0:
        _fail("traffic average work time metric incorrect")
        return

    # A fresh generation uses tick 1 again. Without a reset, an older
    # _last_tick silently starves every decision until the old clock catches
    # up; stale observations and timing samples also survive incorrectly.
    budget.update_sensor(30, {"gap": 1.0})
    budget.select_decisions(100, ids)
    budget.reset_runtime()
    if not budget.cached_sensor(30).is_empty() or budget.metrics()["sample_count"] != 0:
        _fail("new generation inherited sensor cache or timing samples")
        return
    if budget.maximum_agents != 12 or budget.maximum_decisions_per_tick != 2 or budget.sensor_interval_ticks != 4:
        _fail("runtime reset destroyed configured work limits")
        return
    if budget.select_decisions(1, ids) != PackedInt32Array([10, 20]):
        _fail("new generation did not restart decision cursor at first tick")
        return
    if not budget.select_decisions(1, ids).is_empty():
        _fail("reset weakened duplicate-tick protection")
        return
    print("CIVIC_CHAOS_REPLAY_STATE traffic_budget=" + JSON.stringify({
        "window": metrics["sample_count"],
        "peak_us": metrics["peak_us"],
        "average_us": metrics["average_us"],
        "post_reset_samples": budget.metrics()["sample_count"],
        "limits": [budget.maximum_agents, budget.maximum_decisions_per_tick, budget.sensor_interval_ticks]
    }))
    print("CIVIC_CHAOS_TRAFFIC_BUDGET_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
