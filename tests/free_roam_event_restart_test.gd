extends SceneTree
## GAME-023: active Free Roam event carries through verified offline save JSON.
const FreeRoam = preload("res://scripts/civic/free_roam_events.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Repo = preload("res://scripts/core/save_repository.gd")
const PATH: String = "user://game023_free_roam_restart.json"

func _initialize() -> void:
    call_deferred("_run")

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        var candidate: String = PATH + suffix
        if FileAccess.file_exists(candidate):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))

func _environment() -> Dictionary:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        stage.queue_free()
        return {}
    var roam := FreeRoam.new() as CivicFreeRoamEvents
    stage.add_child(roam)
    if not roam.configure(player, civic):
        stage.queue_free()
        return {}
    return {"stage": stage, "player": player, "civic": civic, "roam": roam}

func _activate(roam: CivicFreeRoamEvents) -> void:
    for i in range(20):
        roam._physics_process(0.25)

func _act(roam: CivicFreeRoamEvents, player: Node3D,
        target: CivicCleanupTarget, action: String) -> bool:
    player.position = target.position + Vector3(0.0, 0.0, 1.4)
    target.interact(player)
    return roam.perform_incident_action(player, action)

func _run() -> void:
    _clean()
    var first: Dictionary = _environment()
    if first.is_empty():
        _fail("first physical Free Roam world could not configure")
        return
    var roam: CivicFreeRoamEvents = first["roam"]
    var civic: CivicGameplaySession = first["civic"]
    var player: Node3D = first["player"]
    _activate(roam)
    if roam.active_event.is_empty():
        _fail("no physical civic event available to checkpoint")
        return
    var kind: String = str(roam.active_event["kind"])
    var info: Dictionary = CivicFreeRoamChallenges.details(kind)
    var collect: String = str(info["collect"])
    var place: String = str(info["deposit"])
    if not _act(roam, player, roam.primary, "inspect") or not _act(roam, player, roam.primary, collect):
        _fail("could not acquire real item to save")
        return
    civic.tick = maxi(civic.tick, roam.tick)
    var civic_state: Dictionary = civic.snapshot()
    var live_state: Dictionary = roam.checkpoint_state()
    if not FreeRoam.checkpoint_valid(live_state, civic_state):
        _fail("legitimate mid-carry event checkpoint invalid")
        return
    var tampered: Dictionary = live_state.duplicate(true)
    tampered["active_event"]["incident_id"] = 876543
    if FreeRoam.checkpoint_valid(tampered, civic_state):
        _fail("invented incident identity accepted")
        return
    tampered = live_state.duplicate(true)
    tampered["director"]["active_instances"][0]["id"] = "fake_event"
    if FreeRoam.checkpoint_valid(tampered, civic_state):
        _fail("unscheduled event type accepted")
        return
    var player_state: Dictionary = {"x": player.position.x, "y": 0.1,
        "z": player.position.z, "yaw": 0.0}
    if not Repo.write_save({"player": player_state, "civic_session": civic_state,
            "free_roam_checkpoint": live_state}, PATH):
        _fail("verified offline checkpoint failed write")
        return
    var loaded: Dictionary = Repo.read_save(PATH)
    if loaded.is_empty() or not FreeRoam.checkpoint_valid(
            loaded.get("free_roam_checkpoint"), loaded.get("civic_session")):
        _fail("verified checkpoint failed JSON disk roundtrip")
        return
    var event_id: int = int(live_state["active_event"]["incident_id"])
    var count_before: int = civic.incidents.incidents.size()
    (first["stage"] as Node3D).queue_free()
    await physics_frame
    await physics_frame

    var next: Dictionary = _environment()
    if next.is_empty():
        _fail("new scene could not build civic managers")
        return
    var resumed: CivicFreeRoamEvents = next["roam"]
    var next_civic: CivicGameplaySession = next["civic"]
    var next_player: Node3D = next["player"]
    if not next_civic.restore(loaded["civic_session"]) or not resumed.restore_checkpoint(loaded["free_roam_checkpoint"]):
        _fail("physical Free Roam state could not rebuild from JSON")
        return
    if resumed.active_event.is_empty() or int(resumed.active_event["incident_id"]) != event_id:
        _fail("restarted event changed its audited incident identity")
        return
    if resumed.primary.visible or resumed.primary.collision_layer != 0 or resumed.active_event["stage"] != 2:
        _fail("carried prop respawned on the street")
        return
    if next_civic.incidents.incidents.size() != count_before:
        _fail("restoring event created duplicate incidents")
        return
    if not _act(resumed, next_player, resumed.receiver, place):
        _fail("resumed object could not be placed at physical destination")
        return
    if resumed.resolved_total != 1 or not resumed.director.active.is_empty():
        _fail("event was not resolved once after restart")
        return
    if not next_civic.metrics.processed_events.has("free_roam:%d:resolved" % event_id):
        _fail("resolved event lost its unique score audit")
        return
    if not FreeRoam.checkpoint_valid(resumed.checkpoint_state(), next_civic.snapshot()):
        _fail("post-resolution event history could not be saved")
        return
    var counts: Dictionary = next_civic.metrics.scores.duplicate(true)
    if resumed.perform_incident_action(next_player, place) or next_civic.metrics.scores != counts:
        _fail("replaying completed event duplicated city points")
        return
    (next["stage"] as Node3D).queue_free()
    _clean()
    print("CIVIC_CHAOS_FREE_ROAM_EVENT_RESTART_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    _clean()
    quit(1)
