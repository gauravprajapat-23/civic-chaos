extends SceneTree
## PROG-02: the first neighborhood beacon comes from three real resolved
## incidents, not untrusted UI counters or altered checkpoint fields.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const FreeRoam = preload("res://scripts/civic/free_roam_events.gd")

func _initialize() -> void:
    call_deferred("_run")

func _interact(roam: CivicFreeRoamEvents, actor: Node3D, target: CivicCleanupTarget, action: String) -> bool:
    actor.position = target.position + Vector3(0.0, 0.0, 1.4)
    target.interact(actor)
    return roam.perform_incident_action(actor, action)

func _advance_until_event(roam: CivicFreeRoamEvents) -> bool:
    for step in range(400):
        if not roam.active_event.is_empty():
            return true
        await physics_frame
        roam._physics_process(0.25)
    return false

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var actor := Node3D.new()
    stage.add_child(actor)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    civic.set_physics_process(false)
    if not civic.configure(stage, actor):
        _fail("civic session setup failed")
        return
    var roam := FreeRoam.new() as CivicFreeRoamEvents
    stage.add_child(roam)
    roam.set_physics_process(false)
    if not roam.configure(actor, civic):
        _fail("Free Roam setup failed")
        return
    for solved in range(3):
        if not await _advance_until_event(roam):
            _fail("unable to stage a real civic event at count %d" % solved)
            return
        if is_instance_valid(roam.support_beacon) and roam.support_beacon.visible:
            _fail("navigation aid appeared before the third verified resolution")
            return
        var kind: String = str(roam.active_event["kind"])
        var info: Dictionary = CivicFreeRoamChallenges.details(kind)
        if not _interact(roam, actor, roam.primary, "inspect"):
            _fail("physical evidence inspection failed")
            return
        if not _interact(roam, actor, roam.primary, str(info["collect"])):
            _fail("physical collection failed")
            return
        if not _interact(roam, actor, roam.receiver, str(info["deposit"])):
            _fail("physical handoff did not resolve the incident")
            return
        if roam.resolved_total != solved + 1:
            _fail("resolved count did not advance exactly once")
            return
        if not FreeRoam.checkpoint_valid(roam.checkpoint_state(), civic.snapshot()):
            _fail("real civic state failed checkpoint validation")
            return
        await physics_frame
    if not await _advance_until_event(roam):
        _fail("unlocked neighborhood has no live event to assist")
        return
    if not is_instance_valid(roam.support_beacon) or not roam.support_beacon.visible:
        _fail("earned North Market Watch did not show a physical navigation beacon")
        return
    if roam.support_beacon.get_child_count() != 0:
        _fail("visual beacon unexpectedly contains interactive child nodes")
        return
    var place: Dictionary = CivicFreeRoamChallenges.site(
        str(roam.active_event["site_id"]), str(roam.active_event["kind"]))
    var at: Vector3 = place["source"] + Vector3(0, 2.5, 0)
    if roam.support_beacon.position.distance_to(at) > 0.001:
        _fail("navigation beacon did not point to the physical evidence")
        return
    var previous: Dictionary = roam.checkpoint_state()
    if not roam.restore_checkpoint(previous):
        _fail("existing checkpoint could not restore unlocked support")
        return
    if not is_instance_valid(roam.support_beacon) or not roam.support_beacon.visible:
        _fail("neighborhood support did not reconstruct after checkpoint restoration")
        return
    if roam.checkpoint_state() != previous:
        _fail("visual unlock mutated the saved mission or checkpoint schema")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_NEIGHBORHOOD_UNLOCKS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
