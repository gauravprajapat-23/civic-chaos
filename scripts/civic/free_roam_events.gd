class_name CivicFreeRoamEvents
extends Node3D
## GAME-023 — repeatable physical civic incidents after story completion.
## Deterministic, offline-only, one live incident, no replayable story rewards.
signal incident_card_requested(state: Dictionary)
signal feedback_changed(message: String)
signal incident_resolved(kind: String)

const Target = preload("res://scripts/civic/cleanup_target.gd")
const CHECKPOINT_VERSION: int = 1
const SEED: int = 23077
const COOLDOWN_TICKS: int = 20
const LITTER: String = "civic_litter"
const SIGN: String = "fallen_public_sign"
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
var _current_target: String = ""
var primary: CivicCleanupTarget
var receiver: CivicCleanupTarget
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
    if not active_event.is_empty() or not [LITTER, SIGN].has(kind):
        return false
    if not _stage_targets(kind):
        return false
    var created: Dictionary = session.incidents.create_incident(
        "free_roam_" + kind, 50000 + instance_id, tick, "market_free_roam")
    if not bool(created.get("ok", false)) or bool(created.get("duplicate", false)):
        _clear_targets()
        return false
    active_event = {"kind": kind, "instance": instance_id,
        "incident_id": int(created["id"]), "stage": 0}
    _say("NEW FREE ROAM EVENT | %s. Follow the guide and inspect the physical evidence." %
        ("Litter near the market" if kind == LITTER else "Fallen public sign"))
    return true

func _stage_targets(kind: String) -> bool:
    if primary != null or receiver != null or not is_inside_tree():
        return false
    primary = Target.new() as CivicCleanupTarget
    primary.name = "FreeRoamEvidence"
    primary.configure("litter" if kind == LITTER else "sign", 0,
        "LITTER  |  E / USE" if kind == LITTER else "FALLEN SIGN  |  E / USE")
    primary.position = LITTER_GROUND if kind == LITTER else SIGN_GROUND
    primary.activated.connect(_on_target_activated)
    add_child(primary)
    receiver = Target.new() as CivicCleanupTarget
    receiver.name = "FreeRoamDestination"
    receiver.configure("bin" if kind == LITTER else "stand", 1,
        "RECYCLING BIN  |  E / USE" if kind == LITTER else "SAFE SIGN STAND  |  E / USE")
    receiver.position = LITTER_BIN if kind == LITTER else SIGN_STAND
    receiver.activated.connect(_on_target_activated)
    add_child(receiver)
    return true

func _clear_targets() -> void:
    if is_instance_valid(primary):
        primary.queue_free()
    if is_instance_valid(receiver):
        receiver.queue_free()
    primary = null
    receiver = null
    _current_target = ""

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
    var kind: String = str(active_event["kind"])
    var stage: int = int(active_event["stage"])
    var is_primary: bool = _current_target == "primary"
    var action: String = "collect_litter" if kind == LITTER else "collect_sign"
    var label: String = "Collect wrapper" if kind == LITTER else "Lift fallen sign"
    if not is_primary:
        action = "deposit_litter" if kind == LITTER else "place_sign"
        label = "Use recycling bin" if kind == LITTER else "Place sign on safe stand"
    return {"title": "Free Roam | %s" % ("Litter" if kind == LITTER else "Fallen sign"),
        "location": "Market Chowk walking area",
        "phase": "Evidence" if stage == 0 else "Carrying" if stage == 2 else "Ready",
        "evidence": "A real wrapper needs disposal." if kind == LITTER else "A fallen public sign needs to be returned to its stand.",
        "hint": feedback, "can_inspect": is_primary and stage == 0,
        "can_report": is_primary and stage == 1 or not is_primary and stage == 2,
        "report_action": action, "report_label": label,
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
        return true
    var collect_action: String = "collect_litter" if kind == LITTER else "collect_sign"
    var drop_action: String = "deposit_litter" if kind == LITTER else "place_sign"
    if action == collect_action and _current_target == "primary" and stage == 1:
        active_event["stage"] = 2
        _set_carried(true)
        _say("Collected. Carry it to the %s." % ("green bin" if kind == LITTER else "blue sign stand"))
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
    var changes: Dictionary = {"cooperation": 2, "trust": 1} if kind == LITTER else {"safety": 2, "efficiency": 1}
    if not session.metrics.apply_outcome(outcome_id, tick,
            changes, "physical_civic_intervention"):
        push_error("Free Roam civic metrics rejected a prevalidated physical outcome")
        return false
    director.resolve_instance(instance, tick)
    resolved_total += 1
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
    expired_total += 1
    active_event = {}
    _clear_targets()
    next_spawn_tick = tick + COOLDOWN_TICKS
    _say("A public-space event passed without a player intervention. Another opportunity will appear.")

func guidance_state() -> Dictionary:
    var objective: String = "Explore Market Chowk. New public-space tasks appear periodically."
    var target: Vector3 = Vector3.ZERO
    var available: bool = not active_event.is_empty()
    if available:
        var kind: String = str(active_event["kind"])
        var stage: int = int(active_event["stage"])
        target = (LITTER_GROUND if kind == LITTER else SIGN_GROUND) if stage < 2 else (LITTER_BIN if kind == LITTER else SIGN_STAND)
        objective = ("Inspect the litter" if kind == LITTER else "Inspect the fallen sign") if stage == 0 else (
            "Collect the wrapper" if kind == LITTER else "Lift the sign") if stage == 1 else (
            "Place wrapper in green bin" if kind == LITTER else "Return sign to safe stand")
    return {"title": "Free Roam | Market Chowk",
        "objective": objective, "speaker": "Neighborhood Radio",
        "dialogue": feedback, "target": target, "has_target": available,
        "recovery_available": false}

func hud_state() -> Dictionary:
    return {"free_roam_resolved": resolved_total, "free_roam_expired": expired_total,
        "free_roam_event": str(active_event.get("kind", ""))}

func checkpoint_state() -> Dictionary:
    return {"schema_version": CHECKPOINT_VERSION,
        "tick": tick, "seconds": _seconds,
        "next_spawn_tick": next_spawn_tick,
        "resolved_total": resolved_total, "expired_total": expired_total,
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
    if not _whole(data.get("schema_version"), 1, 1):
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
        if not [LITTER, SIGN].has(kind) or str(current[0].get("id", "")) != kind:
            return false
        if int(current[0].get("instance", -1)) != int(live["instance"]):
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
    var proposed: Dictionary = data["active_event"]
    # Stage any props before changing the event director. No new incidents
    # or metric mutations are created during a restore.
    _clear_targets()
    if not proposed.is_empty() and not _stage_targets(str(proposed["kind"])):
        return false
    if not director.restore_checkpoint(data["director"]):
        _clear_targets()
        return false
    tick = int(data["tick"])
    _seconds = float(data["seconds"])
    next_spawn_tick = int(data["next_spawn_tick"])
    resolved_total = int(data["resolved_total"])
    expired_total = int(data["expired_total"])
    active_event = proposed.duplicate(true)
    if not active_event.is_empty() and int(active_event["stage"]) >= 2:
        _set_carried(true)
    if active_event.is_empty():
        feedback = "Free Roam | Explore the district; another civic activity may appear."
    else:
        feedback = "Restored a live public-space event. Continue from the physical evidence."
    return true

func _say(message: String) -> void:
    feedback = message
    feedback_changed.emit(message)
    if session != null:
        session._publish()
