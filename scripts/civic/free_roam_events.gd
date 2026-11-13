class_name CivicFreeRoamEvents
extends Node3D
## GAME-023 — repeatable physical civic incidents after story completion.
## Deterministic, offline-only, one live incident, no replayable story rewards.
signal incident_card_requested(state: Dictionary)
signal feedback_changed(message: String)
signal incident_resolved(kind: String)
signal npc_reaction_requested(position: Vector3, kind: String, phase: String, instance_id: int)

const Target = preload("res://scripts/civic/cleanup_target.gd")
const Challenges = preload("res://scripts/civic/free_roam_challenges.gd")
const Progression = preload("res://scripts/civic/volunteer_progression.gd")
const Improvements = preload("res://scripts/world/neighborhood_improvements.gd")
const CHECKPOINT_VERSION: int = 2
const SEED: int = 23077
const COOLDOWN_TICKS: int = 20
const LITTER: String = "civic_litter"
const SIGN: String = "fallen_public_sign"
const CONE: String = "misplaced_safety_cone"
const LITTER_GROUND: Vector3 = Vector3(18.5, 0.12, -26.0)
const LITTER_BIN: Vector3 = Vector3(21.0, 0.10, -28.0)
const SIGN_GROUND: Vector3 = Vector3(-15.0, 0.12, -25.5)
const SIGN_STAND: Vector3 = Vector3(-18.0, 0.12, -26.0)
const RANGE_M: float = 3.0

var session: CivicGameplaySession
var player: Node3D
var director: CivicEventDirector
var tick: int = 0
var _seconds: float = 0.0
var next_spawn_tick: int = 0
var resolved_total: int = 0
var expired_total: int = 0
var active_event: Dictionary = {}
var last_location_id: String = ""
var _current_target: String = ""
var primary: CivicCleanupTarget
var receiver: CivicCleanupTarget
## A non-colliding visual aid, reconstructed from audited receipts on load.
## It never grants physical access, changes deadlines, or enters checkpoints.
var support_beacon: MeshInstance3D
var neighborhood_improvements: CivicNeighborhoodImprovements
var feedback: String = "Free Roam | Keep an eye out for civic issues around Market Chowk."

func _init() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

static func new_director() -> CivicEventDirector:
    var value := CivicEventDirector.new()
    if not value.configure(SEED, 1, 1):
        return null
    for entry in [
        {"id": LITTER, "cost": 1, "duration": 180, "cooldown": COOLDOWN_TICKS,
            "tags": ["public_space"], "conditions": {"reputation": 0}},
        {"id": SIGN, "cost": 1, "duration": 180, "cooldown": COOLDOWN_TICKS,
            "tags": ["public_space"], "conditions": {"reputation": 0}},
        {"id": CONE, "cost": 1, "duration": 180, "cooldown": COOLDOWN_TICKS,
            "tags": ["public_space"], "conditions": {"reputation": 0}}
    ]:
        if not value.register_event(entry):
            return null
    return value

func configure(actor: Node3D, civic: CivicGameplaySession) -> bool:
    if actor == null or civic == null or director != null or not is_inside_tree():
        return false
    player = actor
    session = civic
    director = new_director()
    if director == null:
        return false
    tick = maxi(civic.tick, maxi(civic.incidents.current_tick, civic.metrics.last_tick))
    next_spawn_tick = tick + 3
    neighborhood_improvements = Improvements.new() as CivicNeighborhoodImprovements
    neighborhood_improvements.name = "NeighborhoodImprovements"
    add_child(neighborhood_improvements)
    neighborhood_improvements.service_requested.connect(_on_neighborhood_service_requested)
    _sync_improvements()
    return true

func _physics_process(delta: float) -> void:
    if director == null or player == null or session == null or delta <= 0.0:
        return
    _seconds += minf(delta, 0.25)
    if _seconds < 1.0:
        return
    _seconds -= 1.0
    tick += 1
    if active_event.is_empty() and tick < next_spawn_tick:
        return
    # Priority events have a shorter real deadline than the scheduler's
    # maximum lifetime. Closing them early still releases budget exactly once.
    if not active_event.is_empty() and tick >= int(active_event.get("deadline_tick", 1000000000)):
        var deadline_instance: int = int(active_event["instance"])
        if director.active.has(deadline_instance):
            director.resolve_instance(deadline_instance, tick)
        _expire_event()
        return
    var previous_instance: int = int(active_event.get("instance", -1))
    var result: Dictionary = director.advance_to(tick, {"reputation": session.metrics.reputation()})
    if not bool(result.get("ok", false)):
        return
    if previous_instance > 0 and not director.active.has(previous_instance):
        _expire_event()
        # Director may schedule another definition on the expiry tick.
        # Release that scheduling slot, then honor the explicit cooldown.
        if str(result.get("started", "")) != "":
            director.resolve_instance(int(result["instance"]), tick)
        return
    var kind: String = str(result.get("started", ""))
    if kind != "" and active_event.is_empty():
        if not _start_event(kind, int(result["instance"])):
            director.resolve_instance(int(result["instance"]), tick)
            next_spawn_tick = tick + COOLDOWN_TICKS

func _start_event(kind: String, instance_id: int) -> bool:
    if not active_event.is_empty() or not Challenges.all_kinds().has(kind) or not director.active.has(instance_id):
        return false
    if str(director.active[instance_id].get("id", "")) != kind:
        return false
    var site_id: String = Challenges.choose_site(instance_id, last_location_id, Callable(self, "_site_is_safe"))
    if site_id.is_empty() or not _stage_targets(kind, site_id):
        return false
    var created: Dictionary = session.incidents.create_incident(
        "free_roam_" + kind, 50000 + instance_id, tick, "market_free_roam")
    if not bool(created.get("ok", false)) or bool(created.get("duplicate", false)):
        _clear_targets()
        return false
    last_location_id = site_id
    active_event = {"kind": kind, "instance": instance_id,
        "incident_id": int(created["id"]), "stage": 0, "site_id": site_id,
        "tier": Challenges.tier(instance_id),
        "deadline_tick": Challenges.deadline(instance_id, int(director.active[instance_id]["end_tick"]))}
    _sync_support_beacon()
    var info: Dictionary = Challenges.details(kind)
    var place: Dictionary = Challenges.site(site_id, kind)
    _say("NEW %s FREE ROAM EVENT | %s at %s. Inspect the evidence." % [
        str(active_event["tier"]).to_upper(), str(info["title"]), str(place["label"])])
    _notify_witness("spawned")
    return true

func _site_is_safe(site_id: String, ignore_player_distance: bool = false) -> bool:
    var site: Dictionary = Challenges.site(site_id)
    if site.is_empty() or not is_inside_tree():
        return false
    for key in ["source", "destination"]:
        var location: Vector3 = to_global(site[key])
        if not ignore_player_distance and is_instance_valid(player):
            var horizontal: Vector3 = player.global_position - location
            horizontal.y = 0.0
            if horizontal.length_squared() < 16.0:
                return false
        # Probe above the floor to ignore terrain/sidewalk slabs, while
        # refusing buildings, parked cars, props and nearby pedestrians.
        var shape := BoxShape3D.new()
        shape.size = Vector3(1.35, 1.35, 1.35)
        var probe := PhysicsShapeQueryParameters3D.new()
        probe.shape = shape
        probe.transform = Transform3D(Basis.IDENTITY, location + Vector3(0.0, 1.05, 0.0))
        probe.collision_mask = 1 | 4 | 8 | 16
        if player is CollisionObject3D:
            probe.exclude.append((player as CollisionObject3D).get_rid())
        for old_target in [primary, receiver]:
            if is_instance_valid(old_target):
                probe.exclude.append(old_target.get_rid())
        if not get_world_3d().direct_space_state.intersect_shape(probe, 16).is_empty():
            return false
    return true

func _stage_targets(kind: String, site_id: String) -> bool:
    if primary != null or receiver != null or not is_inside_tree():
        return false
    var site: Dictionary = Challenges.site(site_id, kind)
    var info: Dictionary = Challenges.details(kind)
    if site.is_empty() or info.is_empty():
        return false
    primary = Target.new() as CivicCleanupTarget
    primary.name = "FreeRoamEvidence"
    primary.configure(str(info["primary_kind"]), 0, str(info["primary_label"]))
    primary.position = site["source"]
    primary.activated.connect(_on_target_activated)
    add_child(primary)
    receiver = Target.new() as CivicCleanupTarget
    receiver.name = "FreeRoamDestination"
    receiver.configure(str(info["receiver_kind"]), 1, str(info["receiver_label"]))
    receiver.position = site["destination"]
    receiver.activated.connect(_on_target_activated)
    add_child(receiver)
    return true

func _notify_witness(phase: String) -> void:
    if active_event.is_empty():
        return
    var site: Dictionary = Challenges.site(str(active_event["site_id"]), str(active_event["kind"]))
    if not site.is_empty():
        npc_reaction_requested.emit(to_global(site["source"]),
            str(active_event["kind"]), phase, int(active_event["instance"]))

func _on_neighborhood_service_requested(index: int, actor: Node) -> void:
    # E/USE must originate from the actual player at the real service desk.
    # The station grants information, not physical authority or score credits.
    if actor != player or not is_instance_valid(neighborhood_improvements):
        return
    if not neighborhood_improvements.project_visible(index):
        return
    var station: Node3D = neighborhood_improvements.get_node_or_null(
        "Improvement_%d/ServicePoint" % index) as Node3D
    if station == null or player.global_position.distance_to(station.global_position) > 3.0:
        return
    var progress: Dictionary = Progression.overview(
        session.metrics.reputation(), resolved_total, session.metrics.processed_events)
    if progress.is_empty():
        return
    match index:
        0:
            _say("MARKET GARDEN | %d verified civic activities. Next volunteer badge: %s." % [
                resolved_total, str(progress.get("next_title", "All badges earned"))])
        1:
            if active_event.is_empty():
                _say("COMMUNITY KIOSK | No current civic call. Explore the streets for new reports.")
            else:
                var site: Dictionary = Challenges.site(
                    str(active_event["site_id"]), str(active_event["kind"]))
                _say("COMMUNITY KIOSK | Active incident: %s. Location: %s." % [
                    str(active_event["kind"]).replace("_", " ").capitalize(),
                    str(site.get("label", "Market Chowk"))])
        2:
            if active_event.is_empty():
                _say("SOLAR RESPONSE POINT | All clear. Priority monitoring is available.")
            else:
                var seconds_left: int = maxi(0, int(active_event["deadline_tick"]) - tick)
                var urgency: String = "PRIORITY" if str(active_event["tier"]) == "priority" else "ROUTINE"
                _say("SOLAR RESPONSE POINT | %s civic call, %ds remaining." % [
                    urgency, seconds_left])
func _sync_improvements() -> void:
    if not is_instance_valid(neighborhood_improvements) or session == null:
        return
    # Called only after a verified physical completion or checkpoint restore.
    # False/forged progress fails closed without displaying new projects.
    neighborhood_improvements.update_from_receipts(
        session.metrics.reputation(), resolved_total, session.metrics.processed_events)

func _sync_support_beacon() -> void:
    if is_instance_valid(support_beacon):
        support_beacon.visible = false
    if active_event.is_empty() or session == null:
        return
    var progress: Dictionary = Progression.overview(
        session.metrics.reputation(), resolved_total, session.metrics.processed_events)
    if progress.is_empty():
        return
    var support: Dictionary = progress.get("neighborhood_support", {})
    var stage: int = int(active_event["stage"])
    var show: bool = bool(support.get("source_beacon", false)) and stage < 2
    show = show or (bool(support.get("destination_beacon", false)) and stage == 2)
    if not show:
        return
    var site: Dictionary = Challenges.site(str(active_event["site_id"]), str(active_event["kind"]))
    if site.is_empty():
        return
    if not is_instance_valid(support_beacon):
        support_beacon = MeshInstance3D.new()
        support_beacon.name = "NeighborhoodSupportBeacon"
        support_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var sphere := SphereMesh.new()
        sphere.radius = 0.42
        sphere.height = 0.84
        support_beacon.mesh = sphere
        var paint := StandardMaterial3D.new()
        paint.albedo_color = Color(0.15, 0.85, 0.96, 0.85)
        paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        paint.emission_enabled = true
        paint.emission = Color(0.05, 0.7, 1.0)
        support_beacon.material_override = paint
        add_child(support_beacon)
    var priority: bool = bool(support.get("priority_alert", false)) and str(active_event["tier"]) == "priority"
    support_beacon.scale = Vector3.ONE * (1.65 if priority else 1.0)
    var location: Vector3 = site["source"] if stage < 2 else site["destination"]
    support_beacon.position = location + Vector3(0.0, 2.5, 0.0)
    support_beacon.visible = true

func _clear_targets() -> void:
    # queue_free() is deferred. Retire collision and E/USE immediately so a
    # same-frame reload or new incident cannot interact with ghost props.
    for target in [primary, receiver]:
        if is_instance_valid(target):
            target.collision_layer = 0
            target.collision_mask = 0
            target.visible = false
            target.queue_free()
    primary = null
    receiver = null
    _current_target = ""
    if is_instance_valid(support_beacon):
        support_beacon.visible = false

func _set_carried(value: bool) -> void:
    if is_instance_valid(primary):
        primary.visible = not value
        primary.collision_layer = 0 if value else 16

func _on_target_activated(actor: Node, kind: String, slot: int) -> void:
    if not _can_interact(actor, kind):
        return
    _current_target = "primary" if slot == 0 else "receiver"
    incident_card_requested.emit(incident_card_state())

func _actor_for_kind(kind: String) -> CivicCleanupTarget:
    if is_instance_valid(primary) and kind == primary.kind:
        return primary
    if is_instance_valid(receiver) and kind == receiver.kind:
        return receiver
    return null

func _can_interact(actor: Node, kind: String) -> bool:
    if active_event.is_empty() or session == null or actor != player or player == null:
        return false
    var target: CivicCleanupTarget = _actor_for_kind(kind)
    if not is_instance_valid(target) or not target.visible or target.collision_layer != 16:
        return false
    var metres: float = player.global_position.distance_to(target.global_position)
    return metres <= RANGE_M and bool(session.interactions.inspect(
        int(active_event["incident_id"]), metres).get("ok", false))

func incident_card_state() -> Dictionary:
    if active_event.is_empty():
        return {"title": "Free Roam | Public space protected", "phase": "Resolved",
            "hint": feedback, "can_inspect": false, "can_report": false}
    var info: Dictionary = Challenges.details(str(active_event["kind"]))
    var site: Dictionary = Challenges.site(str(active_event["site_id"]), str(active_event["kind"]))
    var stage: int = int(active_event["stage"])
    var is_primary: bool = _current_target == "primary"
    return {"title": "Free Roam | %s" % str(info["title"]),
        "location": str(site["label"]),
        "phase": "%s | %ds remaining" % [str(active_event["tier"]).capitalize(),
            maxi(0, int(active_event["deadline_tick"]) - tick)],
        "evidence": str(info["evidence"]),
        "hint": feedback, "can_inspect": is_primary and stage == 0,
        "can_report": is_primary and stage == 1 or not is_primary and stage == 2,
        "report_action": str(info["collect"]) if is_primary else str(info["deposit"]),
        "report_label": str(info["collect_label"]) if is_primary else str(info["deposit_label"]),
        "reported": stage == 2, "finished": false}

func perform_incident_action(actor: Node, action: String) -> bool:
    if active_event.is_empty():
        return false
    var target: CivicCleanupTarget = primary if _current_target == "primary" else receiver
    if not is_instance_valid(target) or not _can_interact(actor, target.kind):
        return false
    var kind: String = str(active_event["kind"])
    var stage: int = int(active_event["stage"])
    if action == "inspect" and _current_target == "primary" and stage == 0:
        active_event["stage"] = 1
        _say("Evidence inspected. Move it safely to the marked destination.")
        _notify_witness("inspected")
        return true
    var info: Dictionary = Challenges.details(kind)
    var collect_action: String = str(info["collect"])
    var drop_action: String = str(info["deposit"])
    if action == collect_action and _current_target == "primary" and stage == 1:
        active_event["stage"] = 2
        _set_carried(true)
        _sync_support_beacon()
        _say("Collected. Carry it to the %s." % str(info["carry_target"]))
        _notify_witness("carried")
        return true
    if action == drop_action and _current_target == "receiver" and stage == 2:
        return _resolve_event()
    return false

func _resolve_event() -> bool:
    var id: int = int(active_event["incident_id"])
    var instance: int = int(active_event["instance"])
    var outcome_id: String = "free_roam:%d:resolved" % id
    if tick < session.incidents.current_tick or tick < session.metrics.last_tick or session.metrics.processed_events.has(outcome_id):
        return false
    if not director.active.has(instance):
        return false
    if not session.incidents.transition(id, CivicIncidentManager.INTERVENTION, tick, "player_handled_physical_object"):
        return false
    if not session.incidents.transition(id, CivicIncidentManager.RESOLVED, tick, "object_placed_in_safe_destination"):
        return false
    var kind: String = str(active_event["kind"])
    var changes: Dictionary = Challenges.details(kind)["scores"].duplicate(true)
    if str(active_event["tier"]) == "priority":
        changes["trust"] = int(changes.get("trust", 0)) + 1
    if not session.metrics.apply_outcome(outcome_id, tick,
            changes, "physical_civic_intervention"):
        push_error("Free Roam civic metrics rejected a prevalidated physical outcome")
        return false
    director.resolve_instance(instance, tick)
    _notify_witness("resolved")
    resolved_total += 1
    _sync_improvements()
    active_event = {}
    next_spawn_tick = tick + COOLDOWN_TICKS
    _clear_targets()
    _say("FREE ROAM SUCCESS | Public space improved. Civic activities completed: %d." % resolved_total)
    incident_resolved.emit(kind)
    return true

func _expire_event() -> void:
    if active_event.is_empty():
        return
    var id: int = int(active_event["incident_id"])
    session.incidents.transition(id, CivicIncidentManager.INTERVENTION, tick, "unaddressed_event_expired")
    session.incidents.transition(id, CivicIncidentManager.RESOLVED, tick, "incident_cleared_without_player_reward")
    _notify_witness("expired")
    expired_total += 1
    active_event = {}
    _clear_targets()
    next_spawn_tick = tick + COOLDOWN_TICKS
    _say("A public-space event passed without a player intervention. Another opportunity will appear.")

func guidance_state() -> Dictionary:
    var objective: String = "Explore Market Chowk. New public-space tasks appear periodically."
    var target: Vector3 = Vector3.ZERO
    var available: bool = not active_event.is_empty()
    var label: String = "Market Chowk"
    if available:
        var stage: int = int(active_event["stage"])
        var info: Dictionary = Challenges.details(str(active_event["kind"]))
        var site: Dictionary = Challenges.site(str(active_event["site_id"]), str(active_event["kind"]))
        label = str(site["label"])
        target = site["source"] if stage < 2 else site["destination"]
        objective = str(info["inspect_goal"]) if stage == 0 else (
            str(info["collect_goal"]) if stage == 1 else str(info["deposit_goal"]))
        objective += " | %ds left" % maxi(0, int(active_event["deadline_tick"]) - tick)
        if is_instance_valid(support_beacon) and support_beacon.visible:
            objective += " | Follow the blue community beacon"
    return {"title": "Free Roam | %s" % label,
        "objective": objective, "speaker": "Neighborhood Radio",
        "dialogue": feedback, "target": target, "has_target": available,
        "recovery_available": false}

func hud_state() -> Dictionary:
    var result: Dictionary = {"free_roam_resolved": resolved_total, "free_roam_expired": expired_total,
        "free_roam_event": str(active_event.get("kind", "")),
        "free_roam_location": str(active_event.get("site_id", "")),
        "free_roam_priority": str(active_event.get("tier", "")) == "priority"}
    if session != null:
        result["volunteer_progress"] = Progression.overview(
            session.metrics.reputation(), resolved_total, session.metrics.processed_events)
    if is_instance_valid(neighborhood_improvements):
        result["neighborhood_projects"] = neighborhood_improvements.project_state()
    return result

func checkpoint_state() -> Dictionary:
    return {"schema_version": CHECKPOINT_VERSION,
        "tick": tick, "seconds": _seconds,
        "next_spawn_tick": next_spawn_tick,
        "resolved_total": resolved_total, "expired_total": expired_total,
        "last_location_id": last_location_id,
        "active_event": active_event.duplicate(true),
        "director": director.checkpoint_state() if director != null else {}}

static func _whole(raw: Variant, minimum: int, maximum: int) -> bool:
    if not (raw is int or raw is float):
        return false
    var value: float = float(raw)
    return is_finite(value) and value == floorf(value) and value >= float(minimum) and value <= float(maximum)

static func checkpoint_valid(raw: Variant, civic: Variant) -> bool:
    if not (raw is Dictionary) or not (civic is Dictionary):
        return false
    var data: Dictionary = raw
    if not _whole(data.get("schema_version"), 1, CHECKPOINT_VERSION):
        return false
    if not _whole(data.get("tick"), 0, 1000000000):
        return false
    if not (data.get("seconds") is float or data.get("seconds") is int):
        return false
    if not is_finite(float(data["seconds"])) or float(data["seconds"]) < 0.0 or float(data["seconds"]) >= 1.0:
        return false
    for key in ["next_spawn_tick", "resolved_total", "expired_total"]:
        if not _whole(data.get(key), 0, 1000000000):
            return false
    if not (data.get("active_event") is Dictionary):
        return false
    var version: int = int(data["schema_version"])
    if version == CHECKPOINT_VERSION:
        if not (data.get("last_location_id") is String):
            return false
        var last: String = str(data["last_location_id"])
        if not last.is_empty() and not Challenges.SITES.has(last) and not ["legacy_litter", "legacy_sign"].has(last):
            return false
    var scheduler: CivicEventDirector = new_director()
    if scheduler == null or not scheduler.checkpoint_valid(data.get("director")):
        return false
    var state: Dictionary = data["director"]
    if int(state["current_tick"]) > int(data["tick"]):
        return false
    var live: Dictionary = data["active_event"]
    var current: Array = state["active_instances"]
    if live.is_empty():
        if not current.is_empty():
            return false
    else:
        if current.size() != 1 or not _whole(live.get("instance"), 1, 1000000000):
            return false
        if not _whole(live.get("incident_id"), 1, 1000000000) or not _whole(live.get("stage"), 0, 2):
            return false
        var kind: String = str(live.get("kind", ""))
        if not Challenges.all_kinds().has(kind) or (version == 1 and kind == CONE) or str(current[0].get("id", "")) != kind:
            return false
        if int(current[0].get("instance", -1)) != int(live["instance"]):
            return false
        if version == CHECKPOINT_VERSION:
            var location_id: String = str(live.get("site_id", ""))
            if not Challenges.site_valid(location_id, kind) or location_id != str(data["last_location_id"]):
                return false
            var expected_tier: String = "routine" if location_id.begins_with("legacy_") else Challenges.tier(int(live["instance"]))
            var scheduled_end: int = int(current[0]["end_tick"])
            var expected_deadline: int = scheduled_end if location_id.begins_with("legacy_") else Challenges.deadline(int(live["instance"]), scheduled_end)
            if str(live.get("tier", "")) != expected_tier or not _whole(live.get("deadline_tick"), int(data["tick"]) + 1, 1000000200):
                return false
            if int(live["deadline_tick"]) != expected_deadline:
                return false
    if not (civic.get("incidents") is Dictionary) or not (civic.get("metrics") is Dictionary):
        return false
    var manager: CivicIncidentManager = CivicIncidentManager.from_json(JSON.stringify(civic["incidents"]))
    if manager == null or int(data["tick"]) < manager.current_tick:
        return false
    var processed: Variant = civic["metrics"].get("processed_events")
    if not (processed is Dictionary):
        return false
    # Every Free Roam credit comes from a unique audited outcome. Do not
    # accept a saved counter that claims work not recorded by civic metrics.
    var receipts: int = 0
    for event_key in (processed as Dictionary).keys():
        var event_name: String = str(event_key)
        if event_name.begins_with("free_roam:") and event_name.ends_with(":resolved"):
            receipts += 1
    if receipts != int(data["resolved_total"]):
        return false
    if not live.is_empty():
        var id: int = int(live["incident_id"])
        if not manager.incidents.has(id) or (processed as Dictionary).has("free_roam:%d:resolved" % id):
            return false
        var incident: Dictionary = manager.incidents[id]
        if str(incident.get("kind", "")) != "free_roam_" + str(live["kind"]) or str(incident.get("state", "")) != CivicIncidentManager.ACTIVE:
            return false
        if int(incident.get("source_id", -1)) != 50000 + int(live["instance"]):
            return false
    return true

func restore_checkpoint(raw: Variant) -> bool:
    if director == null or session == null or not checkpoint_valid(raw, session.snapshot()):
        return false
    var data: Dictionary = raw
    # Idempotent load: the same already-staged checkpoint must not be
    # rejected by its own active evidence colliders, or respawn duplicates.
    # Static civic/checkpoint validation above still runs before this path.
    if data == checkpoint_state():
        _sync_improvements()
        _sync_support_beacon()
        return true
    var proposed: Dictionary = data["active_event"].duplicate(true)
    var new_last: String = str(data.get("last_location_id", ""))
    if int(data["schema_version"]) == 1 and not proposed.is_empty():
        var kind: String = str(proposed["kind"])
        proposed["site_id"] = "legacy_litter" if kind == LITTER else "legacy_sign"
        proposed["tier"] = "routine"
        proposed["deadline_tick"] = int(data["director"]["active_instances"][0]["end_tick"])
        new_last = str(proposed["site_id"])
    # Preflight before modifying the currently staged props or event director.
    if not proposed.is_empty() and not str(proposed["site_id"]).begins_with("legacy_"):
        if not _site_is_safe(str(proposed["site_id"]), true):
            return false
    _clear_targets()
    if not proposed.is_empty() and not _stage_targets(str(proposed["kind"]), str(proposed["site_id"])):
        return false
    if not director.restore_checkpoint(data["director"]):
        _clear_targets()
        return false
    tick = int(data["tick"])
    _seconds = float(data["seconds"])
    next_spawn_tick = int(data["next_spawn_tick"])
    resolved_total = int(data["resolved_total"])
    expired_total = int(data["expired_total"])
    _sync_improvements()
    active_event = proposed
    last_location_id = new_last
    if not active_event.is_empty() and int(active_event["stage"]) >= 2:
        _set_carried(true)
    _sync_support_beacon()
    if active_event.is_empty():
        feedback = "Free Roam | Explore the district; another civic activity may appear."
    else:
        feedback = "Restored a live public-space event. Continue from the physical evidence."
        _notify_witness("spawned")
    return true

func _say(message: String) -> void:
    feedback = message
    feedback_changed.emit(message)
    if session != null:
        session._publish()
