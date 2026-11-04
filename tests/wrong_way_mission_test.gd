extends SceneTree

const Mission = preload("res://scripts/civic/wrong_way_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var mission := Mission.new()
    assert(mission.setup())
    assert(mission.begin(44))
    assert(not mission.report(1, 1.0))
    for step in range(4):
        assert(mission.advance(2))
    assert(mission.status()["queue"] == 8)
    assert(not mission.report(1, 5.0))
    assert(mission.report(1, 2.0))
    assert(not mission.report(1, 2.0))
    assert(mission.intervene())
    assert(not mission.intervene())
    for step in range(5):
        assert(mission.advance(0))
    assert(mission.status()["queue"] == 0)
    assert(mission.status()["mission"]["state"] == "active")
    for step in range(2):
        assert(mission.advance(0))
    assert(mission.status()["mission"]["state"] == "completed")
    assert(mission.status()["incident"]["state"] == "resolved")
    assert(mission.reward() == 100)
    assert(mission.reward() == 0)
    print("CIVIC_CHAOS_WRONG_WAY_MISSION_PASS")
    quit(0)
