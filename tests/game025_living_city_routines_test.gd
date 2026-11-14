extends SceneTree
## GAME-025-01: story walkers stay on the stable baseline, while
## Free Roam can activate deterministic routines without score or save edits.
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")
const Routine = preload("res://scripts/npc/npc_daily_routine.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var walkers := Walkers.new()
    walkers.pedestrian_count = 0
    root.add_child(walkers)
    await process_frame
    if walkers.daily_routines_enabled or bool(walkers.living_city_summary()["active"]):
        _fail("story campaign unexpectedly activates living city")
        return
    walkers.set_living_city_active(true)
    if not walkers.daily_routines_enabled or not bool(walkers.living_city_summary()["active"]):
        _fail("free roam did not activate residents")
        return
    # Simulated activity names are read-only UI aggregation, not schedule
    # overrides or checkpoint fields.
    walkers._routine_activity = ["commute", "market", "break", "return_home"]
    var snapshot: Dictionary = walkers.living_city_summary()
    var activities: Dictionary = snapshot["activities"]
    if int(activities["commute"]) != 1 or int(activities["market"]) != 1 or int(activities["break"]) != 1 or int(activities["return_home"]) != 1:
        _fail("living city summary counts are wrong")
        return
    for data in [
        {"tick": 100, "name": "commute", "pause": false},
        {"tick": 2200, "name": "market", "pause": false},
        {"tick": 3300, "name": "break", "pause": true},
        {"tick": 4000, "name": "return_home", "pause": false}
    ]:
        var first: Dictionary = Routine.plan(0, int(data["tick"]))
        var second: Dictionary = Routine.plan(0, int(data["tick"]))
        if first != second or not bool(first["ok"]) or first["activity"] != data["name"] or first["pause"] != data["pause"]:
            _fail("deterministic routine schedule changed: " + str(data))
            return
    walkers.set_living_city_active(false)
    if walkers.daily_routines_enabled or bool(walkers.living_city_summary()["active"]):
        _fail("campaign restore did not disable living city")
        return
    walkers.queue_free()
    print("CIVIC_CHAOS_GAME025_LIVING_CITY_ROUTINES_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
