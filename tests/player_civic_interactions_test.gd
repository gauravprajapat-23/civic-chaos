extends SceneTree

const Incidents = preload("res://scripts/civic/incident_manager.gd")
const Missions = preload("res://scripts/civic/mission_manager.gd")
const Service = preload("res://scripts/player/civic_interaction_service.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var incidents := Incidents.new()
    var service := Service.new()
    assert(service.configure(incidents, Missions.new()))
    var id: int = incidents.create_incident("litter", 1, 0, "market")["id"]
    assert(not service.inspect(id, 4.0)["ok"])
    assert(service.inspect(id, 2.0)["ok"])
    assert(not service.begin_action(1, id, "report", 2.0, PackedStringArray(["resolve"])))
    assert(service.begin_action(1, id, "report", 2.0, PackedStringArray(["report"])))
    assert(service.cancel(1))
    assert(not service.confirm(1, 1, 2.0, PackedStringArray(["report"]))["ok"])
    assert(service.begin_action(1, id, "report", 2.0, PackedStringArray(["report"])))
    assert(not service.confirm(1, 1, 4.0, PackedStringArray(["report"]))["ok"])
    assert(incidents.incidents[id]["state"] == "active")
    assert(service.begin_action(1, id, "report", 2.0, PackedStringArray(["report"])))
    assert(service.confirm(1, 1, 2.0, PackedStringArray(["report"]))["ok"])
    assert(incidents.transition(id, "intervention", 2, "marshal"))
    assert(service.begin_action(1, id, "resolve", 2.0, PackedStringArray(["resolve"])))
    assert(service.confirm(1, 3, 2.0, PackedStringArray(["resolve"]))["ok"])
    assert(incidents.incidents[id]["state"] == "resolved")
    print("CIVIC_CHAOS_PLAYER_INTERACTIONS_PASS")
    quit(0)
