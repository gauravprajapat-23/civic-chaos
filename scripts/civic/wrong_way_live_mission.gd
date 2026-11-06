class_name CivicWrongWayLiveMission
extends Node3D
## GAME-012: physical wrong-way car + live stopped followers + civic intervention.
## Unlike CivicWrongWayScenario this never invents a queue from demand counters.
## GAME-013: municipal tow convoy follows a graph-verified legal route.
## Checkpoint persistence (GAME-014) is a separate milestone.
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
const TOW_GAP_M: float = 6.5
const TOW_SPEED_MPS: float = 7.0
const TOW_SWEEP_STEP_M: float = 0.30

var city_graph: CivicRoadGraph
var traffic_system: CivicTrafficSpawner
var session: CivicGameplaySession
var player: Node3D
var marker: CivicWrongWayReportMarker
var offender: CivicVehicleAgent
var marshal: Node3D
var tow_vehicle: CivicVehicleAgent
var tow_cable: MeshInstance3D
var tow_progress_m: float = 0.0
var tow_started: bool = false
var tow_completed: bool = false
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
var starting_distances: Dictionary = {}
var feedback: String = "Spot the wrong-way car and the actual queue."

func _init() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(world: Node3D, actor: Node3D, graph: CivicRoadGraph, civic_session: CivicGameplaySession, spawner: CivicTrafficSpawner = null) -> bool:
    if world == null or actor == null or graph == null or civic_session == null or incident_id >= 0:
        return false
    if not is_inside_tree() or not graph.validate().is_empty():
        return false
    player = actor
    session = civic_session
    city_graph = graph
    traffic_system = spawner
    if not _find_approach():
        return false
    tick = maxi(session.tick, session.incidents.current_tick)
    # Stage first; a blocked entrance must never leave an orphaned civic
    # incident or mission that prevents a later safe retry.
    if not _stage_vehicles():
        _clear_staging()
        push_warning("Wrong-way scene delayed: road occupancy prevents safe staging")
        return false
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
    marker = ReportPoint.new() as CivicWrongWayReportMarker
    marker.name = "WrongWayEvidencePoint"
    marker.position = Vector3(-20.0, 0.2, -5.3) # On the existing north-side pedestrian sidewalk.
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
    if offender.footprint_blocked_at(offender.global_transform):
        return false
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
        starting_distances[car.get_instance_id()] = distance
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
    if tow_started and not tow_completed:
        _advance_tow_convoy(delta)
    if blocker_removed:
        _measure_recovery()
    # Periodic text updates use the existing feedback signal.
    # The main city HUD independently polls the live stopped-car counts.
    if tick % 45 == 0:
        feedback_changed.emit(feedback)

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
        if traffic_system != null:
            obs = traffic_system.apply_stop_line_observation(car, obs)
        if bool(obs.get("detected", false)):
            car.set_lead_observation(float(obs["gap_m"]), float(obs["lead_speed_mps"]))
        else:
            car.clear_lead_observation()
        car.advance_fixed(delta)
        if car.speed_mps > 0.8 and car.lane_distance_m > float(starting_distances.get(car.get_instance_id(), 0.0)) + 0.6:
            moved_ids[car.get_instance_id()] = true
        if blocker_removed and car.speed_mps > 0.8 and (car.current_route_index > 0 or car.lane_distance_m > OFFENDER_DISTANCE + 4.0):
            released_ids[car.get_instance_id()] = true

func _actual_stopped_count() -> int:
    # Never report a zero queue just because the obstruction vanished.
    # Physical follower speeds and current lane positions remain authoritative.
    var count: int = 0
    for car in followers:
        if not is_instance_valid(car) or not car.active:
            continue
        # Queues must be measured from physical motion, never spawn-at-rest.
        var id: int = car.get_instance_id()
        if moved_ids.has(id) and car.current_route_index == 0 and car.speed_mps < 0.35:
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
        status = "Tow complete; verifying traffic flow"
    elif tow_started:
        status = "Municipal tow convoy clearing the legal route"
    elif intervention_tick >= 0:
        status = "Marshal preparing authorized removal"
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
    if intervention_tick >= 0 and not tow_started and tick - intervention_tick >= MARSHAL_SERVICE_TICKS:
        if _start_tow_convoy():
            _announce("City tow service connected. The wrong-way car is being moved along a legal lane.")

## A collision-bearing tow truck leads the offending car backwards at a
## fixed spacing. Both remain physically present until they reach a legal exit;
## there is no button-triggered deletion or instant off-road teleport.
func _start_tow_convoy() -> bool:
    if tow_started or tow_completed or not is_instance_valid(offender):
        return false
    var legal_exits: Array[int] = city_graph.outgoing_legal_lanes(approach_lane_id, 1)
    if not legal_exits.has(exit_lane_id):
        return false
    var truck := VehicleScene.instantiate() as CivicVehicleAgent
    if truck == null:
        return false
    truck.name = "MunicipalTowTruck"
    add_child(truck)
    if not truck.configure(city_graph, PackedInt32Array([approach_lane_id, exit_lane_id]), VehicleProfile.new()):
        truck.queue_free()
        return false
    truck.physics_obstacle_checks_enabled = false # Convoy performs its own swept collision checks.
    var initial_progress: float = OFFENDER_DISTANCE + TOW_GAP_M
    truck.global_transform = _tow_pose(initial_progress, false)
    truck.lane_distance_m = initial_progress
    if truck.footprint_blocked_at(truck.global_transform):
        truck.queue_free()
        return false
    tow_vehicle = truck
    tow_progress_m = initial_progress
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(1.0, 0.68, 0.08)
    var visual := truck.get_node_or_null("Visual") as MeshInstance3D
    if visual != null:
        visual.material_override = paint
    var sign := Label3D.new()
    sign.name = "MunicipalTowLabel"
    sign.text = "CITY TOW SERVICE"
    sign.position = Vector3(0.0, 2.25, 0.0)
    sign.font_size = 40
    sign.pixel_size = 0.006
    truck.add_child(sign)
    var beacon := MeshInstance3D.new()
    beacon.name = "AmberBeacon"
    beacon.position = Vector3(0.0, 2.02, 0.0)
    var beacon_mesh := SphereMesh.new()
    beacon_mesh.radius = 0.20
    beacon_mesh.height = 0.40
    beacon.mesh = beacon_mesh
    var beacon_paint := StandardMaterial3D.new()
    beacon_paint.albedo_color = Color(1.0, 0.58, 0.05)
    beacon_paint.emission_enabled = true
    beacon_paint.emission = Color(0.8, 0.35, 0.01)
    beacon.material_override = beacon_paint
    truck.add_child(beacon)
    tow_cable = MeshInstance3D.new()
    tow_cable.name = "TowLink"
    var cable_mesh := BoxMesh.new()
    cable_mesh.size = Vector3(0.10, 0.10, 1.0)
    tow_cable.mesh = cable_mesh
    var cable_material := StandardMaterial3D.new()
    cable_material.albedo_color = Color(0.15, 0.17, 0.18)
    tow_cable.material_override = cable_material
    add_child(tow_cable)
    tow_started = true
    _update_tow_link()
    return true

## The two directed city lanes form one continuous graph-legal tow route.
## The towed offender remains facing *backwards* until it reaches the exit.
func _tow_pose(progress: float, reverse_facing: bool) -> Transform3D:
    var inbound: CivicLaneData = city_graph.get_lane(approach_lane_id)
    var inbound_length: float = inbound.length_m()
    var lane: CivicLaneData = inbound
    var distance: float = progress
    if progress >= inbound_length:
        lane = city_graph.get_lane(exit_lane_id)
        distance = progress - inbound_length
    var location: Dictionary = CivicVehicleAgent.sample_centerline(lane.centerline, distance)
    var tangent: Vector3 = location["tangent"]
    var heading: float = atan2(-tangent.x, -tangent.z)
    if reverse_facing:
        heading += PI
    return Transform3D(Basis(Vector3.UP, heading), location["position"])

func _tow_route_length() -> float:
    return city_graph.get_lane(approach_lane_id).length_m() + city_graph.get_lane(exit_lane_id).length_m()

func _advance_tow_convoy(delta: float) -> void:
    if not is_instance_valid(tow_vehicle) or not is_instance_valid(offender):
        return
    var remaining: float = maxf(0.0, _tow_route_length() - tow_progress_m)
    if remaining <= 0.01:
        _finish_tow_convoy()
        return
    var travel: float = minf(TOW_SPEED_MPS * delta, remaining)
    # A convoy obeys the central signal and the pedestrian crossing.
    if traffic_system != null:
        var signal_observation: Dictionary = traffic_system.apply_stop_line_observation(
            tow_vehicle, {"detected": false})
        if bool(signal_observation.get("detected", false)):
            var stop_gap: float = maxf(0.0, float(signal_observation["gap_m"]) - tow_vehicle.minimum_gap_m)
            travel = minf(travel, stop_gap)
    if travel <= 0.0001:
        tow_vehicle.speed_mps = 0.0
        return
    # Probe several intermediate footprints, including corners, BEFORE
    # advancing either collision body; nothing may overlap an actor or prop.
    var samples: int = maxi(1, int(ceil(travel / TOW_SWEEP_STEP_M)))
    for index in range(1, samples + 1):
        var candidate_progress: float = tow_progress_m + travel * float(index) / float(samples)
        var tow_pose: Transform3D = _tow_pose(candidate_progress, false)
        var offender_pose: Transform3D = _tow_pose(candidate_progress - TOW_GAP_M, true)
        if tow_vehicle.footprint_blocked_at(tow_pose) or offender.footprint_blocked_at(offender_pose):
            tow_vehicle.speed_mps = 0.0
            return
    tow_progress_m += travel
    tow_vehicle.global_transform = _tow_pose(tow_progress_m, false)
    offender.global_transform = _tow_pose(tow_progress_m - TOW_GAP_M, true)
    var inbound_length: float = city_graph.get_lane(approach_lane_id).length_m()
    if tow_progress_m >= inbound_length:
        tow_vehicle.current_route_index = 1
        tow_vehicle.lane_distance_m = tow_progress_m - inbound_length
    else:
        tow_vehicle.current_route_index = 0
        tow_vehicle.lane_distance_m = tow_progress_m
    tow_vehicle.speed_mps = travel / delta
    _update_tow_link()
    # Only declare physical clearance once the whole convoy reaches the exit.
    if tow_progress_m >= _tow_route_length() - 0.01:
        _finish_tow_convoy()

func _update_tow_link() -> void:
    if not is_instance_valid(tow_cable) or not is_instance_valid(tow_vehicle) or not is_instance_valid(offender):
        return
    var displacement: Vector3 = tow_vehicle.global_position - offender.global_position
    if displacement.length_squared() <= 0.01:
        return
    var cable_length: float = maxf(0.1, displacement.length() - 3.0)
    var box: BoxMesh = tow_cable.mesh as BoxMesh
    box.size = Vector3(0.10, 0.10, cable_length)
    tow_cable.global_position = (tow_vehicle.global_position + offender.global_position) * 0.5 + Vector3.UP * 0.68
    var heading: Vector3 = displacement.normalized()
    tow_cable.rotation.y = atan2(-heading.x, -heading.z)

func _finish_tow_convoy() -> void:
    if tow_completed or not tow_started:
        return
    if tow_progress_m < _tow_route_length() - 0.01:
        return
    tow_completed = true
    blocker_removed = true
    if is_instance_valid(tow_vehicle):
        tow_vehicle.queue_free()
    if is_instance_valid(offender):
        offender.queue_free()
    if is_instance_valid(tow_cable):
        tow_cable.queue_free()
    _announce("Municipal tow reached the legal exit. Watch actual traffic recover.")

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
    if tow_completed and released_ids.size() >= REQUIRED_RELEASED and stopped_count == 0:
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
