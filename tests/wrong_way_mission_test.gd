extends SceneTree
## Headless contract: no bare assert() that can abort before quit(1).
## Replay trace records actual queue/incident/reward state.
const Mission = preload("res://scripts/civic/wrong_way_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var mission := Mission.new()
    if not mission.setup():
        _fail("mission setup failed")
        return
    if not mission.begin(44):
        _fail("mission did not begin")
        return
    if mission.report(1, 1.0):
        _fail("invalid early report accepted")
        return
    for step in range(4):
        if not mission.advance(2):
            _fail("failed advancing initial wrong-way queue at step " + str(step))
            return
    if mission.status()["queue"] != 8:
        _fail("wrong-way queue did not reach eight vehicles")
        return
    if mission.report(1, 5.0):
        _fail("out-of-range report accepted")
        return
    if not mission.report(1, 2.0) or mission.report(1, 2.0):
        _fail("valid civic report failed or was awarded twice")
        return
    if not mission.intervene() or mission.intervene():
        _fail("tow intervention failed or was accepted twice")
        return
    for step in range(8):
        if not mission.advance(0):
            _fail("failed clearing wrong-way queue at step " + str(step))
            return
    if mission.status()["queue"] != 0 or mission.status()["mission"]["state"] != "active":
        _fail("queue did not clear while the mission remained active")
        return
    for step in range(2):
        if not mission.advance(0):
            _fail("failed finishing wrong-way mission at step " + str(step))
            return
    var status: Dictionary = mission.status()
    if status["mission"]["state"] != "completed" or status["incident"]["state"] != "resolved":
        _fail("mission/incident completion state did not resolve")
        return
    var first_reward: int = mission.reward()
    var duplicate_reward: int = mission.reward()
    if first_reward != 100 or duplicate_reward != 0:
        _fail("wrong-way mission reward was missing or duplicated")
        return
    print("CIVIC_CHAOS_REPLAY_STATE wrong_way=" + JSON.stringify({
        "queue": status["queue"],
        "mission": status["mission"]["state"],
        "incident": status["incident"]["state"],
        "reward": first_reward,
        "duplicate_reward": duplicate_reward
    }))
    print("CIVIC_CHAOS_WRONG_WAY_MISSION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
