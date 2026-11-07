extends SceneTree
## GAME-023: real two-step civic actions with physical props and capped spawns.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const FreeRoam = preload("res://scripts/civic/free_roam_events.gd")

func _initialize() -> void:
    call_deferred("_run")

func _act(roam: CivicFreeRoamEvents, actor: Node3D, source: CivicCleanupTarget, action: String) -> bool:
    actor.position = source.position + Vector3(0.0, 0.0, 1.4)
    source.interact(actor)
    return roam.perform_incident_action(actor, action)

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    stage.add_child(player)
    var session := Session.new() as CivicGameplaySession
    stage.add_child(session)
    if not session.configure(stage, player):
        _fail("civic session was not configured")
        return
    var roam := FreeRoam.new() as CivicFreeRoamEvents
    stage.add_child(roam)
    if not roam.configure(player, session):
        _fail("free-roam system could not configure")
        return
    if not FreeRoam.checkpoint_valid(roam.checkpoint_state(), session.snapshot()):
        _fail("initial Free Roam snapshot not valid")
        return
    for i in range(20):
        roam._physics_process(0.25)
    if roam.active_event.is_empty() or roam.director.active.size() != 1:
        _fail("no seeded physical civic event appeared")
        return
    var kind: String = str(roam.active_event["kind"])
    var first: CivicCleanupTarget = roam.primary
    var destination: CivicCleanupTarget = roam.receiver
    var info: Dictionary = CivicFreeRoamChallenges.details(kind)
    var collect: String = str(info["collect"])
    var place: String = str(info["deposit"])
    if not is_instance_valid(first) or not is_instance_valid(destination):
        _fail("real incident props were not staged")
        return
    if _act(roam, player, first, collect):
        _fail("physical object collected before inspection")
        return
    if _act(roam, player, destination, place):
        _fail("item placed without carrying it")
        return
    if not _act(roam, player, first, "inspect") or not _act(roam, player, first, collect):
        _fail("evidence inspection or physical pickup failed")
        return
    if first.visible or first.collision_layer != 0:
        _fail("carried object still occupies the street")
        return
    var event_id: int = int(roam.active_event["incident_id"])
    var saved: Dictionary = roam.checkpoint_state()
    if not FreeRoam.checkpoint_valid(saved, session.snapshot()):
        _fail("carried object could not be saved")
        return
    var forged: Dictionary = saved.duplicate(true)
    forged["active_event"]["stage"] = 3
    if FreeRoam.checkpoint_valid(forged, session.snapshot()):
        _fail("forged carry state accepted")
        return
    if not _act(roam, player, destination, place):
        _fail("physical destination did not resolve civic incident")
        return
    # The nodes are still alive until queue_free is flushed at frame end.
    # They must already be inert to the next raycast and physical spawn.
    if is_instance_valid(first) and (first.collision_layer != 0 or first.visible):
        _fail("resolved evidence left an interactable ghost collider")
        return
    if is_instance_valid(destination) and (destination.collision_layer != 0 or destination.visible):
        _fail("resolved receiving prop left an interactable ghost collider")
        return
    if not roam.active_event.is_empty() or roam.resolved_total != 1 or roam.director.budget != 1:
        _fail("resolved event left a pending interaction or leaked budget")
        return
    if not session.metrics.processed_events.has("free_roam:%d:resolved" % event_id):
        _fail("real civic recovery did not record a single scoring receipt")
        return
    if session.incidents.incidents[event_id]["state"] != CivicIncidentManager.RESOLVED:
        _fail("physical civic incident was not resolved")
        return
    var score_after: Dictionary = session.metrics.scores.duplicate(true)
    if roam.perform_incident_action(player, place) or score_after != session.metrics.scores:
        _fail("repeated action farmed civic points")
        return
    for i in range(100):
        roam._physics_process(0.25)
    if roam.active_event.is_empty() or roam.director.active.size() > 1:
        _fail("cooldown did not generate another bounded incident")
        return
    if int(roam.active_event["incident_id"]) == event_id:
        _fail("repeatable event reused a prior incident identity")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_FREE_ROAM_LIVE_EVENTS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
