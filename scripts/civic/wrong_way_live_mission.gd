class_name CivicWrongWayLiveMission
extends Node3D
## GAME-012: physical wrong-way car + live stopped followers + civic intervention.
## Unlike CivicWrongWayScenario this never invents a queue from demand counters.
## GAME-013/014 still need a legal tow route, dynamic dispatch and persistence.
signal incident_card_requested(state: Dictionary)
signal feedback_changed(message: String)
signal mission_completed

const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const VehicleProfile = preload("res://scripts/traffic/vehicle_profile.gd")
const ReportPoint = preload("res://scripts/civic/wrong_way_report_marker.gd")
const MISSION_ID: String = "market_wrong_way_live"
const OFFENDER_DISTANCE: float = 28.0
const REPORT_DISTANCE: float = 3.0
const REQUIRED_STOPPED: int = 2
const REQUIRED_RELEASED: int = 2
const MARSHAL_DISPATCH_TICKS: int = 24
const MARSHAL_SERVICE_TICKS: int = 35
const RECOVERY_FRAMES: int = 12

var city_graph: CivicRoadGraph
var session: CivicGameplaySession
var player: Node3D
var marker: CivicWrongWayReportMarker
var offender: CivicVehicleAgent
var marshal: Node3D
var followers: Array[CivicVehicleAgent] = []
var approach_lane_id: int = -1
var exit_lane_id: int = -1
var incident_id: int = -1
var tick: int = 0
var stopped_count: int = 0
var peak_stopped: int = 0
var queue_observed: bool = false
var inspected: bool = false
var reported_tick: int = -1
var intervention_tick: int = -1
var blocker_removed: bool = false
var finished: bool = false
var recovery_streak: int = 0
var released_ids: Dictionary = {}
var moved_ids: Dictionary = {}
var feedback: String = "Spot the wrong-way car and the actual queue."

func _init() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(world: Node3D, actor: Node3D, graph: CivicRoadGraph, civic_session: CivicGameplaySession) -> bool:
    if world == null or actor == null or graph == null or civic_session == null or incident_id >= 0:
        return false
    if not is_inside_tree() or not graph.validate().is_empty():
        return false
    player = actor
    session = civic_session
    city_graph = graph
    if not _find_approach():
        return false
    tick = maxi(session.tick, session.incidents.current_tick)
    var created: Dictionary = session.incidents.create_incident("wrong_way_driving", 901, tick, "market_west_approach")
    if not bool(created.get("ok", false)):
        return false
    incident_id = int(created["id"])
    if not session.missions.register_mission({"id": MISSION_ID, "reward": 100, "objectives": [
        {"event": "congestion_observed", "target": 1},
        {"event": "incident_reported", "target": 1},
        {"event": "marshal_intervened", "target": 1},
        {"event": "sustained_recovery", "target": 1}
    ]}) or not session.missions.start(MISSION_ID):
        return false
    if not _stage_vehicles():
        _clear_staging()
        push_warning("Wrong-way live mission could not safely stage vehicles")
        return false
    marker = ReportPoint.new() as CivicWrongWayReportMarker
    marker.name = "WrongWayEvidencePoint"
    marker.position = Vector3(-20.0, 0.2, -6.5)
    add_child(marker)
    marker.activated.connect(_on_marker_activated)
    _announce("A driver is driving the wrong way near Market Chowk! Watch the traffic.")
    return true

func _find_approach() -> bool:
    # Main road: (-46,0,0) -> (0,0,0), not a synthetic test lane.
    for id in city_graph.sorted_lane_ids():
        var lane: CivicLaneData = city_graph.get_lane(id)
        var origin: Vector3 = lane.centerline[0]
        var destination: Vector3 = lane.centerline[lane.centerline.size() - 1]
        if origin.distance_to(Vector3(-46, 0, 0)) > 0.1 or destination.distance_to(Vector3.ZERO) > 0.1:
            continue
        approach_lane_id = id
        for next_id in city_graph.outgoing_legal_lanes(id, 1):
            var next_lane: CivicLaneData = city_graph.get_lane(next_id)
            var last: Vector3 = next_lane.centerline[next_lane.centerline.size() - 1]
            if last.distance_to(Vector3(46, 0, 0)) < 0.1:
                exit_lane_id = next_id
                return true
    return false

func _stage_vehicles() -> bool:
    var lane: CivicLaneData = city_graph.get_lane(approach_lane_id)
    offender = VehicleScene.instantiate() as CivicVehicleAgent
    offender.name = "WrongWayOffender"
    add_child(offender)
    # Non-configured offender is stationary traffic geometry and never joins
    # legal route navigation. It is initially seen moving backwards against
    # lane direction, then blocks until the authorized service arrives.
    _place_offender(OFFENDER_DISTANCE + 3.0)
    var body := offender.get_node_or_null("Visual") as MeshInstance3D
    if body != null:
        var red := StandardMaterial3D.new()
        red.albedo_color = Color(0.87, 0.14, 0.16)
        body.material_override = red
    var warning := Label3D.new()
    warning.name = "ViolationLabel"
    warning.text = "WRONG WAY"
    warning.position = Vector3(0, 2.6, 0)
    warning.font_size = 48
    warning.pixel_size = 0.007
    offender.add_child(warning)
    for distance in [1.0, 6.0, 11.0, 16.0]:
        var car := VehicleScene.instantiate() as CivicVehicleAgent
        car.name = "QueuedVehicle_%d" % followers.size()
        add_child(car)
        if not car.configure(city_graph, PackedInt32Array([approach_lane_id, exit_lane_id]), VehicleProfile.new()):
            car.queue_free()
            return false
        car.lane_distance_m = distance
        car._place_on_lane()
        car.physics_obstacle_checks_enabled = true
        # This is a full physical footprint check against existing city cars
        # and props; never force a spawned vehicle inside another road user.
        if car.footprint_blocked_at(car.global_transform):
            car.queue_free()
            return false
        followers.append(car)
    return followers.size() >= REQUIRED_STOPPED

func _place_offender(distance: float) -> void:
    if not is_instance_valid(offender):
        return
    var lane: CivicLaneData = city_graph.get_lane(approach_lane_id)
    var sampled: Dictionary = CivicVehicleAgent.sample_centerline(lane.centerline, distance)
    offender.global_position = sampled["position"]
    var reverse: Vector3 = -sampled["tangent"]
    offender.rotation.y = atan2(-reverse.x, -reverse.z)

func _clear_staging() -> void:
    if is_instance_valid(offender):
        offender.queue_free()
    for car in followers:
        if is_instance_valid(car):
            car.queue_free()
    followers.clear()

func _physics_process(delta: float) -> void:
    if incident_id < 0 or finished:
        return
    if delta <= 0.0:
        return
    tick += 1
    if is_instance_valid(offender) and reported_tick < 0:
        var drift: float = maxf(0.0, 3.0 - float(tick) * delta * 2.0)
        _place_offender(OFFENDER_DISTANCE + drift)
    _advance_cars(delta)
    stopped_count = _actual_stopped_count()
    peak_stopped = maxi(peak_stopped, stopped_count)
    if reported_tick >= 0:
        _advance_marshal(delta)
    if blocker_removed:
        _measure_recovery()
    if tick % 45 == 0:
        _publish()

func _advance_cars(delta: float) -> void:
    # Probe all leads before advancing any follower, like CivicTrafficSpawner.
    var observations: Dictionary = {}
    for car in followers:
        if is_instance_valid(car) and car.active:
            observations[car.get_instance_id()] = CivicTrafficSensor.nearest_lead(car, followers)
    for car in followers:
        if not is_instance_valid(car) or not car.active:
            continue
        var obs: Dictionary = observations.get(car.get_instance_id(), {"detected": false})
        if bool(obs.get("detected", false)):
            car.set_lead_observation(float(obs["gap_m"]), float(obs["lead_speed_mps"]))
        else:
            car.clear_lead_observation()
        car.advance_fixed(delta)
        if car.lane_distance_m > 17.0 or car.current_route_index > 0:
            moved_ids[car.get_instance_id()] = true
        if blocker_removed and car.speed_mps > 0.8 and (car.current_route_index > 0 or car.lane_distance_m > OFFENDER_DISTANCE + 4.0):
            released_ids[car.get_instance_id()] = true

func _actual_stopped_count() -> int:
    if blocker_removed:
        return 0
    var count: int = 0
    for car in followers:
        if not is_instance_valid(car) or not car.active:
            continue
        # Queues must be measured from physical motion, never spawn-at-rest.
        if car.lane_distance_m > 17.0 and car.current_route_index == 0 and car.speed_mps < 0.35:
            count += 1
    return count

func _on_marker_activated(actor: Node) -> void:
    if not _can_interact(actor):
        _announce("Use the sidewalk report post. Keep a safe distance from traffic.")
        return
    incident_card_requested.emit(incident_card_state())

func _can_interact(actor: Node) -> bool:
    if actor == null or actor != player or not is_instance_valid(marker) or finished:
        return false
    var distance: float = player.global_position.distance_to(marker.global_position)
    return bool(session.interactions.inspect(incident_id, distance).get("ok", false))

func incident_card_state() -> Dictionary:
    var observed: bool = inspected
    var status: String = "Watch the actual queue"
    if finished:
        status = "Traffic restored"
    elif blocker_removed:
        status = "Obstruction removed; verifying traffic flow"
    elif intervention_tick >= 0:
        status = "Marshal at scene"
    elif reported_tick >= 0:
        status = "Authorized service requested"
    elif inspected:
        status = "Evidence collected"
    return {
        "title": "Wrong Way, Wrong Day",
        "location": "Market Chowk west approach",
        "evidence": "A red vehicle faces oncoming traffic. %d vehicles currently stopped; peak %d." % [stopped_count, peak_stopped],
        "phase": status,
        "hint": feedback,
        "can_inspect": not inspected and stopped_count >= REQUIRED_STOPPED and not finished,
        "can_report": inspected and reported_tick < 0 and not finished,
        "reported": reported_tick >= 0,
        "finished": finished
    }

func perform_incident_action(actor: Node, action: String) -> bool:
    if not _can_interact(actor):
        _announce("Approach the report post on the sidewalk; do not enter traffic.")
        return false
    if action == "inspect":
        if inspected or stopped_count < REQUIRED_STOPPED:
            _announce("Wait until the real traffic queue becomes visible.")
            return false
        if not session.missions.record_event(MISSION_ID, "congestion_observed"):
            return false
        inspected = true
        _announce("Confirmed: the wrong-way car is blocking real traffic. You can report it.")
        return true
    if action != "report" or not inspected or reported_tick >= 0:
        return false
    var distance: float = player.global_position.distance_to(marker.global_position)
    var permissions := PackedStringArray(["report"])
    if not session.interactions.begin_action(0, incident_id, "report", distance, permissions):
        return false
    var result: Dictionary = session.interactions.confirm(0, tick, distance, permissions)
    if not bool(result.get("ok", false)):
        return false
    if not session.missions.record_event(MISSION_ID, "incident_reported"):
        return false
    reported_tick = tick
    _announce("Report received. Marshal dispatched to remove the obstruction safely.")
    return true

func _advance_marshal(delta: float) -> void:
    if intervention_tick < 0 and tick - reported_tick >= MARSHAL_DISPATCH_TICKS:
        if not is_instance_valid(marshal):
            _create_marshal()
        var target := Vector3(-19.5, 0.0, -4.3)
        marshal.global_position = marshal.global_position.move_toward(target, 2.5 * delta)
        if marshal.global_position.distance_to(target) < 0.15:
            if session.incidents.transition(incident_id, CivicIncidentManager.INTERVENTION, tick, "authorized_marshal_arrived"):
                intervention_tick = tick
                session.missions.record_event(MISSION_ID, "marshal_intervened")
                _announce("Marshal arrived. The driver is being directed out of the lane.")
    if intervention_tick >= 0 and not blocker_removed and tick - intervention_tick >= MARSHAL_SERVICE_TICKS:
        # GAME-013 will replace staged authorized removal with a legal tow route.
        if is_instance_valid(offender):
            offender.queue_free()
        blocker_removed = true
        _announce("Wrong-way obstruction removed; observing actual traffic release.")

func _create_marshal() -> void:
    marshal = Node3D.new()
    marshal.name = "TrafficMarshal"
    marshal.position = Vector3(-19.5, 0.0, -8.0)
    add_child(marshal)
    var actor := MeshInstance3D.new()
    actor.name = "MarshalUniform"
    actor.position.y = 0.95
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.38
    mesh.height = 1.9
    actor.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.88, 0.72, 0.22)
    actor.material_override = material
    marshal.add_child(actor)
    var caption := Label3D.new()
    caption.text = "TRAFFIC MARSHAL"
    caption.position.y = 2.1
    caption.font_size = 44
    caption.pixel_size = 0.006
    marshal.add_child(caption)

func _measure_recovery() -> void:
    if released_ids.size() >= REQUIRED_RELEASED and stopped_count == 0:
        recovery_streak += 1
    else:
        recovery_streak = 0
    if recovery_streak < RECOVERY_FRAMES:
        return
    if session.incidents.transition(incident_id, CivicIncidentManager.RESOLVED, tick, "physical_cars_released"):
        session.missions.record_event(MISSION_ID, "sustained_recovery")
        session.metrics.apply_outcome("wrong_way:%d:cleared" % incident_id, tick,
            {"safety": 20, "efficiency": 30, "cooperation": 10}, "measured_congestion_recovery")
        var reward: int = session.missions.claim_reward(MISSION_ID)
        finished = true
        if is_instance_valid(marker):
            marker.queue_free()
        _announce("Wrong-way mission complete! %d cars resumed; civic reward +%d." % [released_ids.size(), reward])
        mission_completed.emit()

func _announce(message: String) -> void:
    feedback = message
    feedback_changed.emit(message)
    _publish()

func _publish() -> void:
    if session == null:
        return
    # Main HUD owns presentation; the mission supplies live measurements only.
    session._publish()

func hud_state() -> Dictionary:
    if session == null:
        return {}
    return {
        "mission": (session.missions.missions.get(MISSION_ID, {}) as Dictionary).duplicate(true),
        "incidents": 0 if finished else 1,
        "scores": session.metrics.scores.duplicate(true),
        "reputation": session.metrics.reputation(),
        "feedback": feedback,
        "incident_queue": stopped_count,
        "incident_peak_queue": peak_stopped
    }
