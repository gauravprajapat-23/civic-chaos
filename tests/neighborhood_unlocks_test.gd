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
    if not is_instance_valid(roam.neighborhood_improvements) or not roam.neighborhood_improvements.project_visible(0):
        _fail("real third resolution did not improve the public planter in the city")
        return
    if roam.neighborhood_improvements.project_visible(1) or roam.neighborhood_improvements.project_visible(2):
        _fail("unearned projects were revealed before ten or twenty-five completions")
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
    var garden: CivicNeighborhoodService = roam.neighborhood_improvements.get_node(
        "Improvement_0/ServicePoint") as CivicNeighborhoodService
    var locked: CivicNeighborhoodService = roam.neighborhood_improvements.get_node(
        "Improvement_1/ServicePoint") as CivicNeighborhoodService
    if garden == null or locked == null or garden.collision_layer != 16 or locked.collision_layer != 0:
        _fail("earned and locked neighborhood services have invalid E/USE access")
        return
    var prior_scores: Dictionary = civic.metrics.scores.duplicate(true)
    var prior_rewards: Dictionary = civic.metrics.processed_events.duplicate(true)
    var old_feedback: String = roam.feedback
    # The previous delivery can happen within the garden's 3m radius.
    # Make the remote rejection deterministic instead of assuming distance.
    actor.global_position = garden.global_position + Vector3(0.0, 0.0, 10.0)
    if actor.global_position.distance_to(garden.global_position) <= 3.0:
        _fail("remote-access fixture was not actually outside service range")
        return
    garden.interact(actor)
    if roam.feedback != old_feedback:
        _fail("remote garden use incorrectly provided civic information")
        return
    actor.global_position = garden.global_position + Vector3(0.0, 0.0, 1.3)
    var impostor := Node3D.new()
    stage.add_child(impostor)
    impostor.global_position = actor.global_position
    garden.interact(impostor)
    if roam.feedback != old_feedback:
        _fail("unauthorized nearby actor could use the garden service")
        return
    garden.interact(actor)
    if not roam.feedback.contains("MARKET GARDEN") or not roam.feedback.contains("3 verified"):
        _fail("earned garden service did not provide verified progress")
        return
    var after_garden: String = roam.feedback
    locked.interact(actor)
    if roam.feedback != after_garden:
        _fail("locked neighborhood service was usable")
        return
    if civic.metrics.scores != prior_scores or civic.metrics.processed_events != prior_rewards:
        _fail("project interaction modified civic points or completion receipts")
        return
    var previous: Dictionary = roam.checkpoint_state()
    if not FreeRoam.checkpoint_valid(previous, civic.snapshot()):
        _fail("live checkpoint invalid before attempting idempotent restoration")
        return
    if not roam.restore_checkpoint(previous):
        _fail("existing checkpoint could not restore unlocked support")
        return
    if not is_instance_valid(roam.support_beacon) or not roam.support_beacon.visible:
        _fail("neighborhood support did not reconstruct after checkpoint restoration")
        return
    if roam.checkpoint_state() != previous:
        _fail("visual unlock mutated the saved mission or checkpoint schema")
        return
    if not roam.neighborhood_improvements.project_visible(0):
        _fail("checkpoint restore did not rebuild earned city improvement")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_NEIGHBORHOOD_UNLOCKS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
