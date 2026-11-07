extends SceneTree
## GAME-024: changing safe locations, priority expiry, action variety and save tamper rejection.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const FreeRoam = preload("res://scripts/civic/free_roam_events.gd")
const Challenges = preload("res://scripts/civic/free_roam_challenges.gd")

func _initialize() -> void:
    call_deferred("_run")

func _reject_all(_name: String) -> bool:
    return false

func _act(roam: CivicFreeRoamEvents, player: Node3D,
        prop: CivicCleanupTarget, action: String) -> bool:
    player.position = prop.position + Vector3(0.0, 0.0, 1.3)
    prop.interact(player)
    return roam.perform_incident_action(player, action)

func _run() -> void:
    var all_sites: Array[String] = Challenges.site_names()
    if all_sites.size() < 6 or Challenges.choose_site(1, "", Callable(self, "_reject_all")) != "":
        _fail("site selector skipped physical occupancy checks")
        return
    var last: String = ""
    for instance_id in range(1, 30):
        var selected: String = Challenges.choose_site(instance_id, last)
        if selected.is_empty() or selected == last:
            _fail("site choices repeated immediately or could not be generated")
            return
        var site: Dictionary = Challenges.site(selected)
        if (site["source"] as Vector3).distance_to(site["destination"]) < 2.0:
            _fail("evidence and receiving prop share the same occupied position")
            return
        last = selected
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic session could not start")
        return
    var roam := FreeRoam.new() as CivicFreeRoamEvents
    stage.add_child(roam)
    roam.set_physics_process(false)
    if not roam.configure(player, civic):
        _fail("free roam could not start")
        return
    var reactions: Array[String] = []
    roam.npc_reaction_requested.connect(func(_at: Vector3, _kind: String, phase: String, _instance: int) -> void:
        reactions.append(phase)
    )
    var visited: Dictionary = {}
    var seen_kinds: Dictionary = {}
    for round_id in range(1, 4):
        var found: bool = false
        for frame in range(160):
            await physics_frame
            roam._physics_process(0.25)
            if not roam.active_event.is_empty():
                found = true
                break
        if not found:
            _fail("no event available after bounded cooldown")
            return
        var event: Dictionary = roam.active_event
        var site_id: String = str(event["site_id"])
        var kind: String = str(event["kind"])
        var layout: Dictionary = Challenges.site(site_id, kind)
        var details: Dictionary = Challenges.details(kind)
        seen_kinds[kind] = true
        if visited.has(site_id):
            _fail("location repeated before visiting the available catalog")
            return
        visited[site_id] = true
        if roam.primary.position != layout["source"] or roam.receiver.position != layout["destination"]:
            _fail("physical props did not match checkpointed location")
            return
        var state: Dictionary = roam.checkpoint_state()
        if not FreeRoam.checkpoint_valid(state, civic.snapshot()):
            _fail("authentic dynamic event rejected by checkpoint validator")
            return
        var forged: Dictionary = state.duplicate(true)
        forged["active_event"]["site_id"] = "unknown_place"
        if FreeRoam.checkpoint_valid(forged, civic.snapshot()):
            _fail("forged out-of-bounds incident location accepted")
            return
        forged = state.duplicate(true)
        forged["active_event"]["deadline_tick"] = int(event["deadline_tick"]) + 1
        if FreeRoam.checkpoint_valid(forged, civic.snapshot()):
            _fail("forged challenge deadline accepted")
            return
        if round_id == 3:
            if str(event["tier"]) != "priority":
                _fail("third incident did not introduce a real priority challenge")
                return
            var scores_before: Dictionary = civic.metrics.scores.duplicate(true)
            for frame in range((Challenges.PRIORITY_TICKS + 2) * 4):
                await physics_frame
                roam._physics_process(0.25)
                if roam.expired_total > 0:
                    break
            if roam.expired_total != 1 or not roam.active_event.is_empty():
                _fail("ignored urgent event did not expire at priority deadline")
                return
            if civic.metrics.scores != scores_before or roam.director.budget != 1:
                _fail("urgent expiry granted points or leaked event budget")
                return
            break
        if not _act(roam, player, roam.primary, "inspect"):
            _fail("inspection did not work at relocated evidence")
            return
        if not _act(roam, player, roam.primary, str(details["collect"])):
            _fail("physical pickup did not match its challenge type")
            return
        if not _act(roam, player, roam.receiver, str(details["deposit"])):
            _fail("physical destination did not resolve its challenge type")
            return
        if roam.resolved_total != round_id:
            _fail("event earned duplicate or missing score receipts")
            return
    if reactions.count("spawned") < 3 or reactions.count("resolved") != 2 or not reactions.has("expired"):
        _fail("NPC reaction notifications did not match physical incident lifecycle")
        return
    if not FreeRoam.checkpoint_valid(roam.checkpoint_state(), civic.snapshot()):
        _fail("resolved and expired event sequence lost its checkpoint validity")
        return
    # All three kind definitions must be physically executable, including cones.
    for kind in Challenges.all_kinds():
        var info: Dictionary = Challenges.details(kind)
        if info.is_empty() or not ["collect_litter", "collect_sign", "collect_cone"].has(str(info["collect"])):
            _fail("missing challenge action: %s" % kind)
            return
    stage.queue_free()
    print("CIVIC_CHAOS_FREE_ROAM_DYNAMIC_LOCATIONS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
