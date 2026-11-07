class_name CivicMarketCleanupMission
extends Node3D
## GAME-021: visibly collected litter, finite bin, and cooperative sanitation.
## Recovery is measured from actual deposited props and worker arrival.
signal incident_card_requested(state: Dictionary)
signal feedback_changed(message: String)
signal mission_completed

const Target = preload("res://scripts/civic/cleanup_target.gd")
const MISSION_ID: String = "market_cleanup_chain"
const CHECKPOINT_VERSION: int = 1
const INTERACT_DISTANCE: float = 3.0
const BIN_CAPACITY: int = 2
const ITEM_POSITIONS: Array[Vector3] = [
    Vector3(12.0, 0.15, -31.0),
    Vector3(13.0, 0.15, -34.0),
    Vector3(11.5, 0.15, -37.0)
]
const BIN_POSITION: Vector3 = Vector3(15.0, 0.10, -39.0)
const HELPER_START: Vector3 = Vector3(10.5, 0.0, -41.0)
const HELPER_DESTINATION: Vector3 = Vector3(13.0, 0.0, -39.0)
const HELPER_SPEED: float = 1.25

var session: CivicGameplaySession
var player: Node3D
var incident_id: int = -1
var tick: int = 0
var targets: Array[CivicCleanupTarget] = []
var market_bin: CivicCleanupTarget
var helper: CivicCleanupTarget
var item_states: Array[int] = [0, 0, 0] # ground=0, carried=1, deposited=2
var inspected: bool = false
var carried_index: int = -1
var deposited_count: int = 0
var bin_fill: int = 0
var service_requested_tick: int = -1
var service_completed: bool = false
var finished: bool = false
var feedback: String = "Market Chowk has litter. Inspect a wrapper from a safe walking space."
var _active_kind: String = ""
var _active_slot: int = -1

func _init() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(world: Node3D, actor: Node3D, civic_session: CivicGameplaySession) -> bool:
    if not prepare_restore(world, actor, civic_session):
        return false
    var incident: Dictionary = session.incidents.create_incident("market_litter", 2101, tick, "market_north_sidewalk")
    if not bool(incident.get("ok", false)) or bool(incident.get("duplicate", false)):
        return false
    incident_id = int(incident["id"])
    if not session.missions.register_mission({
        "id": MISSION_ID, "reward": 90, "objectives": [
            {"event": "litter_evidence", "target": 1},
            {"event": "litter_deposited", "target": ITEM_POSITIONS.size()},
            {"event": "bin_serviced", "target": 1},
            {"event": "market_recovered", "target": 1}
        ]
    }) or not session.missions.start(MISSION_ID):
        return false
    _say("New incident: wrappers at Market Chowk. Inspect one, use the bin, and contact sanitation if it fills.")
    return true

## World actors can be built without altering mission/incident history.
func prepare_restore(world: Node3D, actor: Node3D, civic_session: CivicGameplaySession) -> bool:
    if world == null or actor == null or civic_session == null or not is_inside_tree() or not targets.is_empty():
        return false
    session = civic_session
    player = actor
    tick = maxi(session.tick, maxi(session.incidents.current_tick, session.metrics.last_tick))
    for index in range(ITEM_POSITIONS.size()):
        var item := Target.new() as CivicCleanupTarget
        item.configure("litter", index, "LITTER %d  |  E / USE" % (index + 1))
        item.name = "MarketLitter_%d" % index
        item.position = ITEM_POSITIONS[index]
        item.activated.connect(_on_target_activated)
        add_child(item)
        targets.append(item)
    market_bin = Target.new() as CivicCleanupTarget
    market_bin.configure("bin", -1, "MARKET BIN 0 / 2")
    market_bin.name = "MarketWasteBin"
    market_bin.position = BIN_POSITION
    market_bin.activated.connect(_on_target_activated)
    add_child(market_bin)
    helper = Target.new() as CivicCleanupTarget
    helper.configure("helper", -1, "SANITATION HELPER  |  E / USE")
    helper.name = "SanitationHelper"
    helper.position = HELPER_START
    helper.activated.connect(_on_target_activated)
    add_child(helper)
    return true

func _physics_process(delta: float) -> void:
    if incident_id < 0 or finished or delta <= 0.0:
        return
    tick += 1
    if service_requested_tick >= 0 and not service_completed:
        helper.position = helper.position.move_toward(HELPER_DESTINATION, HELPER_SPEED * delta)
        if helper.position.distance_to(HELPER_DESTINATION) <= 0.015:
            helper.position = HELPER_DESTINATION
            if session.incidents.transition(incident_id, CivicIncidentManager.INTERVENTION, tick, "sanitation_worker_physically_arrived"):
                service_completed = true
                bin_fill = 0
                session.missions.record_event(MISSION_ID, "bin_serviced")
                _refresh_bin()
                helper.caption.text = "BIN EMPTIED!  THANK YOU"
                _say("Sanitation arrived and emptied the real bin. The remaining litter can now go in.")
    if service_completed and deposited_count == ITEM_POSITIONS.size():
        _finish_if_clean()

func _on_target_activated(actor: Node, kind: String, slot: int) -> void:
    if not _can_interact(actor, kind, slot):
        _say("Use E / USE near the litter, bin, or helper from within three metres.")
        return
    _active_kind = kind
    _active_slot = slot
    incident_card_requested.emit(incident_card_state())

func _target(kind: String, slot: int) -> CivicCleanupTarget:
    if kind == "litter" and slot >= 0 and slot < targets.size():
        return targets[slot]
    if kind == "bin":
        return market_bin
    if kind == "helper":
        return helper
    return null

func _can_interact(actor: Node, kind: String, slot: int) -> bool:
    if actor != player or finished or session == null or incident_id < 0:
        return false
    var target: CivicCleanupTarget = _target(kind, slot)
    if not is_instance_valid(target) or not target.visible or target.collision_layer != 16:
        return false
    var distance_m: float = player.global_position.distance_to(target.global_position)
    return distance_m <= INTERACT_DISTANCE and bool(session.interactions.inspect(incident_id, distance_m).get("ok", false))

func incident_card_state() -> Dictionary:
    var phase := "Inspect evidence"
    var hint := feedback
    var action := "collect_litter"
    var action_label := "Collect wrapper"
    var can_inspect: bool = false
    var can_action: bool = false
    var evidence: String = "%d / %d wrappers deposited; bin %d / %d" % [
        deposited_count, ITEM_POSITIONS.size(), bin_fill, BIN_CAPACITY
    ]
    if _active_kind == "litter":
        can_inspect = not inspected and _active_slot >= 0 and item_states[_active_slot] == 0
        can_action = inspected and carried_index < 0 and _active_slot >= 0 and item_states[_active_slot] == 0
        phase = "Wrapper on ground" if not inspected else "Evidence recorded"
        hint = "Carry one wrapper at a time and place it inside the green bin."
    elif _active_kind == "bin":
        action = "deposit_litter"
        action_label = "Place carried wrapper in bin"
        can_action = carried_index >= 0 and bin_fill < BIN_CAPACITY
        phase = "Bin full: request sanitation" if bin_fill >= BIN_CAPACITY else "Space available"
        hint = "Carry one wrapper to the bin. A full bin must be emptied before reuse."
    elif _active_kind == "helper":
        action = "request_service"
        action_label = "Ask sanitation to empty bin"
        can_action = bin_fill >= BIN_CAPACITY and service_requested_tick < 0 and inspected
        phase = "Sanitation on the way" if service_requested_tick >= 0 else "Municipal worker available"
        hint = "Ask the worker only after observing a full bin."
    return {
        "title": "Market Clean-Up Chain", "location": "Market Chowk north walkway",
        "evidence": evidence, "phase": phase, "hint": hint,
        "can_inspect": can_inspect, "can_report": can_action,
        "report_action": action, "report_label": action_label,
        "reported": service_requested_tick >= 0, "finished": finished
    }

func perform_incident_action(actor: Node, action: String) -> bool:
    if not _can_interact(actor, _active_kind, _active_slot):
        return false
    if action == "inspect":
        if _active_kind != "litter" or inspected or item_states[_active_slot] != 0:
            return false
        if not session.missions.record_event(MISSION_ID, "litter_evidence"):
            return false
        inspected = true
        _say("Evidence inspected: three wrappers, one bin with capacity for two.")
        return true
    if action == "collect_litter":
        if _active_kind != "litter" or not inspected or carried_index >= 0 or item_states[_active_slot] != 0:
            return false
        carried_index = _active_slot
        item_states[carried_index] = 1
        _refresh_items()
        _say("Wrapper collected. Carry it to the green bin, then press E / USE.")
        return true
    if action == "deposit_litter":
        if _active_kind != "bin" or carried_index < 0 or bin_fill >= BIN_CAPACITY:
            return false
        item_states[carried_index] = 2
        carried_index = -1
        deposited_count += 1
        bin_fill += 1
        if not session.missions.record_event(MISSION_ID, "litter_deposited"):
            return false
        _refresh_bin()
        _say("Actual bin: %d / %d. %d wrapper(s) still need disposal." % [
            bin_fill, BIN_CAPACITY, ITEM_POSITIONS.size() - deposited_count
        ])
        if service_completed and deposited_count == ITEM_POSITIONS.size():
            _finish_if_clean()
        return true
    if action == "request_service":
        if _active_kind != "helper" or service_requested_tick >= 0 or bin_fill < BIN_CAPACITY or not inspected:
            return false
        var distance_m: float = player.global_position.distance_to(helper.global_position)
        var permissions := PackedStringArray(["report"])
        if not session.interactions.begin_action(0, incident_id, "report", distance_m, permissions):
            return false
        var acknowledged: Dictionary = session.interactions.confirm(0, tick, distance_m, permissions)
        if not bool(acknowledged.get("ok", false)):
            return false
        service_requested_tick = tick
        _say("Sanitation helper: I'll come and empty that full bin. Please keep the walkway clear.")
        return true
    return false

func _refresh_items() -> void:
    for index in range(targets.size()):
        var visible_item: bool = item_states[index] == 0
        targets[index].visible = visible_item
        targets[index].collision_layer = 16 if visible_item else 0

func _refresh_bin() -> void:
    if is_instance_valid(market_bin):
        market_bin.caption.text = "MARKET BIN %d / %d" % [bin_fill, BIN_CAPACITY]

func _finish_if_clean() -> void:
    if finished or deposited_count != ITEM_POSITIONS.size() or not service_completed or carried_index >= 0:
        return
    if not session.incidents.transition(incident_id, CivicIncidentManager.RESOLVED, tick, "all_real_litter_deposited_after_service"):
        return
    session.missions.record_event(MISSION_ID, "market_recovered")
    session.metrics.apply_outcome("cleanup:%d:recovered" % incident_id, tick,
        {"cooperation": 25, "trust": 15, "efficiency": 10}, "verified_market_litter_cleanup")
    var reward: int = session.missions.claim_reward(MISSION_ID)
    finished = true
    helper.caption.text = "MARKET CLEAN!  THANKS"
    _say("All wrappers disposed and the bin serviced. Market Clean-Up +%d points." % reward)
    mission_completed.emit()

func snapshot() -> Dictionary:
    var progress: float = 0.0
    if is_instance_valid(helper):
        var path_length: float = HELPER_START.distance_to(HELPER_DESTINATION)
        progress = clampf(HELPER_START.distance_to(helper.position) / path_length, 0.0, 1.0)
    return {
        "schema_version": CHECKPOINT_VERSION, "incident_id": incident_id,
        "tick": tick, "item_states": item_states.duplicate(), "inspected": inspected,
        "carrying": carried_index, "deposited_count": deposited_count,
        "bin_fill": bin_fill, "service_requested_tick": service_requested_tick,
        "service_progress": progress, "service_completed": service_completed,
        "finished": finished, "feedback": feedback
    }

static func _whole(value: Variant, lower: int, upper: int) -> bool:
    if not (value is int or value is float):
        return false
    var number: float = float(value)
    return is_finite(number) and number == floorf(number) and number >= float(lower) and number <= float(upper)

static func checkpoint_valid(raw: Variant, civic: Variant, failures: Array = []) -> bool:
    if not (raw is Dictionary) or not (civic is Dictionary):
        failures.append("shape")
        return false
    var data: Dictionary = raw
    var state: Dictionary = civic
    for key in ["schema_version", "incident_id", "tick", "carrying", "deposited_count", "bin_fill", "service_requested_tick"]:
        if not _whole(data.get(key), -1, 1000000000):
            failures.append(key)
            return false
    if int(data["schema_version"]) != CHECKPOINT_VERSION or int(data["incident_id"]) < 1 or int(data["tick"]) < 0:
        failures.append("identity")
        return false
    for key in ["inspected", "service_completed", "finished"]:
        if not (data.get(key) is bool):
            failures.append(key)
            return false
    if not (data.get("feedback") is String) or not (data.get("item_states") is Array) or data["item_states"].size() != ITEM_POSITIONS.size():
        failures.append("items")
        return false
    var carried: int = 0
    var disposed: int = 0
    for index in range(ITEM_POSITIONS.size()):
        if not _whole(data["item_states"][index], 0, 2):
            failures.append("item_state")
            return false
        if int(data["item_states"][index]) == 1:
            carried += 1
            if int(data["carrying"]) != index:
                failures.append("carried_identity")
                return false
        if int(data["item_states"][index]) == 2:
            disposed += 1
    if carried > 1 or (carried == 0 and int(data["carrying"]) != -1) or (carried == 1 and not bool(data["inspected"])):
        failures.append("inventory")
        return false
    if disposed != int(data["deposited_count"]) or disposed < 0 or disposed > ITEM_POSITIONS.size():
        failures.append("disposed")
        return false
    if not _whole(data["bin_fill"], 0, BIN_CAPACITY) or not _whole(data["service_requested_tick"], -1, int(data["tick"])):
        failures.append("service_tick")
        return false
    if not (data.get("service_progress") is float or data.get("service_progress") is int):
        failures.append("service_progress")
        return false
    var progress: float = float(data["service_progress"])
    if not is_finite(progress) or progress < 0.0 or progress > 1.0:
        failures.append("service_progress_bounds")
        return false
    var service_started: bool = int(data["service_requested_tick"]) >= 0
    if service_started and (not bool(data["inspected"]) or disposed < BIN_CAPACITY):
        failures.append("premature_service")
        return false
    if not service_started and (progress > 0.001 or bool(data["service_completed"])):
        failures.append("unrequested_service")
        return false
    if bool(data["service_completed"]) != (progress >= 0.999):
        failures.append("worker_not_arrived")
        return false
    var expected_bin: int = disposed if not bool(data["service_completed"]) else disposed - BIN_CAPACITY
    if int(data["bin_fill"]) != expected_bin or expected_bin < 0 or expected_bin > BIN_CAPACITY:
        failures.append("bin_volume")
        return false
    if bool(data["finished"]) != (disposed == ITEM_POSITIONS.size() and bool(data["service_completed"])):
        failures.append("completion")
        return false
    if not (state.get("incidents") is Dictionary) or not (state.get("missions") is Dictionary) or not (state.get("metrics") is Dictionary):
        failures.append("civic")
        return false
    var incident_manager: CivicIncidentManager = CivicIncidentManager.from_json(JSON.stringify(state["incidents"]))
    var mission_manager := CivicMissionManager.new()
    if incident_manager == null or not mission_manager.restore(state["missions"]):
        failures.append("managers")
        return false
    var incident_id_value: int = int(data["incident_id"])
    if not incident_manager.incidents.has(incident_id_value) or not mission_manager.missions.has(MISSION_ID):
        failures.append("mission_missing")
        return false
    if int(data["tick"]) < incident_manager.current_tick:
        failures.append("clock")
        return false
    var incident: Dictionary = incident_manager.incidents[incident_id_value]
    if incident.get("kind") != "market_litter" or int(incident.get("source_id", -1)) != 2101 or incident.get("location_key") != "market_north_sidewalk":
        failures.append("wrong_incident")
        return false
    var mission: Dictionary = mission_manager.missions[MISSION_ID]
    var counts: Dictionary = mission.get("progress", {})
    var expected: Dictionary = {
        "litter_evidence": int(bool(data["inspected"])),
        "litter_deposited": disposed,
        "bin_serviced": int(bool(data["service_completed"])),
        "market_recovered": int(bool(data["finished"]))
    }
    for key in expected.keys():
        if not counts.has(key) or not _whole(counts[key], 0, ITEM_POSITIONS.size()) or int(counts[key]) != expected[key]:
            failures.append("objective_" + key)
            return false
    var state_name: String = str(incident.get("state", ""))
    var expected_state: String = CivicIncidentManager.RESOLVED if bool(data["finished"]) else CivicIncidentManager.INTERVENTION if bool(data["service_completed"]) else CivicIncidentManager.ESCALATED if service_started else CivicIncidentManager.ACTIVE
    if state_name != expected_state:
        failures.append("incident_phase")
        return false
    if bool(data["finished"]) != (mission.get("state") == CivicMissionManager.COMPLETED) or bool(data["finished"]) != mission_manager.rewarded.has(MISSION_ID):
        failures.append("reward")
        return false
    var scores: Dictionary = state["metrics"]
    var events: Dictionary = scores.get("processed_events", {})
    if not (events is Dictionary) or events.has("cleanup:%d:recovered" % incident_id_value) != bool(data["finished"]):
        failures.append("score_once")
        return false
    return true

func restore(raw: Variant) -> bool:
    if session == null or not checkpoint_valid(raw, session.snapshot()):
        return false
    var data: Dictionary = raw
    if incident_id >= 0 and incident_id != int(data["incident_id"]):
        return false
    if targets.size() != ITEM_POSITIONS.size() or not is_instance_valid(market_bin) or not is_instance_valid(helper):
        return false
    incident_id = int(data["incident_id"])
    tick = int(data["tick"])
    inspected = bool(data["inspected"])
    for index in range(ITEM_POSITIONS.size()):
        item_states[index] = int(data["item_states"][index])
    carried_index = int(data["carrying"])
    deposited_count = int(data["deposited_count"])
    bin_fill = int(data["bin_fill"])
    service_requested_tick = int(data["service_requested_tick"])
    service_completed = bool(data["service_completed"])
    finished = bool(data["finished"])
    feedback = str(data["feedback"])
    helper.position = HELPER_START.lerp(HELPER_DESTINATION, float(data["service_progress"]))
    helper.caption.text = "MARKET CLEAN!  THANKS" if finished else "BIN EMPTIED!  THANK YOU" if service_completed else "SANITATION HELPER  |  E / USE"
    _refresh_items()
    _refresh_bin()
    _active_kind = ""
    _active_slot = -1
    return true

func guidance_state() -> Dictionary:
    var objective := "Inspect any wrapper to document the littering."
    var target: Vector3 = ITEM_POSITIONS[0]
    if not inspected:
        for index in range(ITEM_POSITIONS.size()):
            if item_states[index] == 0:
                target = ITEM_POSITIONS[index]
                break
    elif carried_index >= 0:
        objective = "Carry the wrapper to the green bin (%d / %d)." % [bin_fill, BIN_CAPACITY]
        target = BIN_POSITION
    elif bin_fill == BIN_CAPACITY and not service_completed:
        objective = "The bin is full. Ask the sanitation helper to empty it." if service_requested_tick < 0 else "Watch the sanitation helper physically reach the bin."
        target = HELPER_START if service_requested_tick < 0 else HELPER_DESTINATION
    elif not finished:
        objective = "Collect remaining wrappers. Deposited: %d / %d." % [deposited_count, ITEM_POSITIONS.size()]
        for index in range(ITEM_POSITIONS.size()):
            if item_states[index] == 0:
                target = ITEM_POSITIONS[index]
                break
    else:
        objective = "Market clean! All wrappers disposed and the bin serviced."
    return {
        "title": "Market Clean-Up Chain", "objective": objective,
        "speaker": "Neighborhood Radio",
        "dialogue": feedback,
        "target": target, "has_target": not finished,
        "recovery_available": false
    }

func _say(message: String) -> void:
    feedback = message
    feedback_changed.emit(message)
    if session != null:
        session._publish()
