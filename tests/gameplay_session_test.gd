extends SceneTree
## First real 3D civic loop: inspect/report -> service -> collider removed -> reward.
const Session = preload("res://scripts/civic/gameplay_session.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    player.name = "PlayerRoot"
    player.position = Vector3(20, 0.21, -14)
    stage.add_child(player)
    var session: CivicGameplaySession = Session.new() as CivicGameplaySession
    stage.add_child(session)
    if not session.configure(stage, player):
        _fail("session failed to configure")
        return
    if session.try_interact_at_marker(player):
        _fail("out-of-range inspection was accepted")
        return
    player.position = Vector3(5, 0.21, -12)
    if not session.try_interact_at_marker(player):
        _fail("inspection failed in range")
        return
    var entry: Dictionary = session.missions.missions[Session.MISSION_ID]
    if int(entry["progress"]["obstruction_observed"]) != 1:
        _fail("observed event did not advance objective")
        return
    if not session.try_interact_at_marker(player):
        _fail("authorized report failed")
        return
    if session.try_interact_at_marker(player):
        _fail("repeat report was wrongly accepted")
        return
    if not is_instance_valid(session.marker):
        _fail("obstruction disappeared before authorized cleanup")
        return
    for frame in range(160):
        await physics_frame
    if not session.finished or is_instance_valid(session.marker):
        _fail("world obstruction remained after service response")
        return
    var incident: Dictionary = session.incidents.incidents[session.incident_id]
    if incident["state"] != CivicIncidentManager.RESOLVED:
        _fail("incident not resolved after collider removal")
        return
    entry = session.missions.missions[Session.MISSION_ID]
    if entry["state"] != CivicMissionManager.COMPLETED:
        _fail("mission did not complete after world recovered")
        return
    if session.metrics.scores["efficiency"] != 525 or session.metrics.scores["cooperation"] != 515:
        _fail("city scores do not reflect exactly one real recovery")
        return
    if session.missions.claim_reward(Session.MISSION_ID) != 0:
        _fail("mission reward could be duplicated")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_GAMEPLAY_SESSION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
