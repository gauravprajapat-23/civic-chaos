extends SceneTree
## GAME-024: GAME-023 v1 active-event saves migrate to canonical v2 on F9.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const FreeRoam = preload("res://scripts/civic/free_roam_events.gd")
const Challenges = preload("res://scripts/civic/free_roam_challenges.gd")

func _initialize() -> void:
    call_deferred("_run")

func _environment() -> Dictionary:
    var stage := Node3D.new()
    root.add_child(stage)
    var actor := Node3D.new()
    stage.add_child(actor)
    var session := Session.new() as CivicGameplaySession
    stage.add_child(session)
    # Free Roam drives its own logical event tick in this isolated fixture.
    # Awaited physics frames must not independently advance tutorial metrics.
    session.set_physics_process(false)
    if not session.configure(stage, actor):
        return {}
    var events := FreeRoam.new() as CivicFreeRoamEvents
    stage.add_child(events)
    events.set_physics_process(false)
    if not events.configure(actor, session):
        return {}
    return {"stage": stage, "actor": actor, "session": session, "events": events}

func _act(events: CivicFreeRoamEvents, actor: Node3D, target: CivicCleanupTarget, action: String) -> bool:
    actor.position = target.position + Vector3(0.0, 0.0, 1.4)
    target.interact(actor)
    return events.perform_incident_action(actor, action)

func _run() -> void:
    var initial: Dictionary = _environment()
    if initial.is_empty():
        _fail("could not start legacy migration fixture")
        return
    var events: CivicFreeRoamEvents = initial["events"]
    var actor: Node3D = initial["actor"]
    var session: CivicGameplaySession = initial["session"]
    for attempt in range(8):
        for frame in range(160):
            await physics_frame
            events._physics_process(0.25)
            if not events.active_event.is_empty():
                break
        if events.active_event.is_empty():
            _fail("no legacy-compatible event found")
            return
        var kind: String = str(events.active_event["kind"])
        if kind != Challenges.CONE:
            break
        var info: Dictionary = Challenges.details(kind)
        if not _act(events, actor, events.primary, "inspect") or not _act(events, actor, events.primary, str(info["collect"])) or not _act(events, actor, events.receiver, str(info["deposit"])):
            _fail("could not advance past the first cone event")
            return
    if events.active_event.is_empty() or str(events.active_event["kind"]) == Challenges.CONE:
        _fail("litter/sign legacy fixture not reached")
        return
    var kind: String = str(events.active_event["kind"])
    var info: Dictionary = Challenges.details(kind)
    if not _act(events, actor, events.primary, "inspect") or not _act(events, actor, events.primary, str(info["collect"])):
        _fail("could not save legacy mid-carry event")
        return
    # This fixture deliberately disables the session's automatic physics
    # clock while manually driving Free Roam. In production the session clock
    # advances alongside incident creation/transitions; restore correctly
    # rejects an unfinished tutorial snapshot older than its own incidents.
    # Reconcile the fixture's clock before taking the paired checkpoint.
    session.tick = maxi(session.tick, maxi(events.tick,
        maxi(session.incidents.current_tick, session.metrics.last_tick)))
    var civic_state: Dictionary = session.snapshot()
    if not session.can_restore(civic_state):
        _fail("fixture produced an unrestorable civic session before migration")
        return
    var legacy: Dictionary = events.checkpoint_state()
    legacy["schema_version"] = 1
    legacy.erase("last_location_id")
    legacy["active_event"].erase("site_id")
    legacy["active_event"].erase("tier")
    legacy["active_event"].erase("deadline_tick")
    if not FreeRoam.checkpoint_valid(legacy, civic_state):
        _fail("canonical GAME-023-style checkpoint was rejected")
        return
    var incident_id: int = int(legacy["active_event"]["incident_id"])
    (initial["stage"] as Node3D).queue_free()
    await physics_frame
    await physics_frame
    var restored: Dictionary = _environment()
    if restored.is_empty():
        _fail("could not rebuild world for legacy restore")
        return
    var new_session: CivicGameplaySession = restored["session"]
    var new_events: CivicFreeRoamEvents = restored["events"]
    var new_actor: Node3D = restored["actor"]
    if not new_session.restore(civic_state):
        _fail("civic session could not restore before legacy migration")
        return
    if not new_events.restore_checkpoint(legacy):
        _fail("GAME-023 Free Roam event could not migrate to GAME-024")
        return
    var expected_site: String = "legacy_litter" if kind == Challenges.LITTER else "legacy_sign"
    if str(new_events.active_event.get("site_id", "")) != expected_site:
        _fail("legacy evidence lost its original fixed world location")
        return
    if new_events.primary.visible or new_events.primary.collision_layer != 0:
        _fail("legacy mid-carry item was duplicated after migration")
        return
    var upgraded: Dictionary = new_events.checkpoint_state()
    if int(upgraded["schema_version"]) != 2 or not FreeRoam.checkpoint_valid(upgraded, new_session.snapshot()):
        _fail("migrated event cannot be safely re-saved as schema v2")
        return
    if not _act(new_events, new_actor, new_events.receiver, str(info["deposit"])):
        _fail("legacy event could not finish at its original destination")
        return
    if not new_session.metrics.processed_events.has("free_roam:%d:resolved" % incident_id):
        _fail("migrated event did not keep its unique audited score receipt")
        return
    (restored["stage"] as Node3D).queue_free()
    print("CIVIC_CHAOS_FREE_ROAM_LEGACY_MIGRATION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
