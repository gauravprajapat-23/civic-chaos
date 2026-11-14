class_name CivicWrongWayLiveMission
extends Node3D
## GAME-012: physical wrong-way car + live stopped followers + civic intervention.
## Unlike CivicWrongWayScenario this never invents a queue from demand counters.
## GAME-013: municipal tow convoy follows a graph-verified legal route.
## GAME-014: versioned actor-index checkpoints with safe rehydration.
signal incident_card_requested(state: Dictionary)
signal feedback_changed(message: String)
signal mission_completed

const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const VehicleProfile = preload("res://scripts/traffic/vehicle_profile.gd")
const CharacterArt = preload("res://scripts/rendering/low_poly_character.gd")
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
const SERVICE_LIFT_HEIGHT_M: float = 4.0
const SERVICE_LIFT_SPEED_MPS: float = 2.0
const SERVICE_HOLD_BEFORE_LIFT_FRAMES: int = 180
const CHECKPOINT_VERSION: int = 1
const CHECKPOINT_DISTANCE_EPS_M: float = 0.02
const RECOVERY_STALL_TICKS: int = 1800 # Diagnostic prompt only; never auto-fail the mission.

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
var offender_distance_m: float = OFFENDER_DISTANCE + 3.0
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
var _last_progress_tick: int = -1
var _last_progress_signature: String = ""
var _stalled: bool = false
var _tow_hold_reason: String = ""
var _tow_hold_frames: int = 0
var service_lift_height_m: float = 0.0
var tow_recovered_on_site: bool = false

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
    offender_distance_m = distance
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
        if service_lift_height_m > 0.0:
            _advance_service_lift(delta)
        else:
            _advance_tow_convoy(delta)
    if blocker_removed:
        _measure_recovery()
    _update_recovery_watchdog()
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
        # Count real vehicles that pass the *former* blockage while the
        # towed offender is already clear of it. Waiting until the tow has
        # fully left the district would miss cars that finished their route.
        var old_obstruction_clear: bool = tow_started and (tow_progress_m - TOW_GAP_M) >= OFFENDER_DISTANCE + 6.0
        # A car that has actually passed the incident is released even if it
        # subsequently brakes for the normal junction light or ends its route.
        # Movement before passing is required; never manufacture a release.
        if (blocker_removed or old_obstruction_clear) and moved_ids.has(car.get_instance_id()) and _passed_incident(car):
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
        if moved_ids.has(id) and not _passed_incident(car) and car.speed_mps < 0.35:
            count += 1
    return count

## Distinguish the incident's upstream queue from ordinary vehicles waiting
## at the downstream traffic light. Normal signal stops must never prevent
## the sustained-recovery objective after the obstruction is gone.
static func _passed_incident(car: CivicVehicleAgent) -> bool:
    if car == null:
        return false
    return car.current_route_index > 0 or car.lane_distance_m > OFFENDER_DISTANCE + 6.0

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
    _last_progress_tick = tick
    _last_progress_signature = ""
    _stalled = false
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
func _start_tow_convoy(restore_progress: float = -1.0) -> bool:
    if tow_started or tow_completed or not is_instance_valid(offender):
        return false
    # The towing service must never operate before a real authorized report
    # and a marshal's physical arrival/incident state transition.
    if reported_tick < 0 or intervention_tick < 0:
        return false
    if session.incidents.incidents[incident_id]["state"] != CivicIncidentManager.INTERVENTION:
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
    var initial_progress: float = OFFENDER_DISTANCE + TOW_GAP_M if restore_progress < 0.0 else restore_progress
    truck.global_transform = _tow_pose(initial_progress, false)
    var inbound_length: float = city_graph.get_lane(approach_lane_id).length_m()
    truck.current_route_index = 1 if initial_progress >= inbound_length else 0
    truck.lane_distance_m = initial_progress - inbound_length if truck.current_route_index == 1 else initial_progress
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
    if restore_progress >= 0.0:
        offender.global_transform = _tow_pose(restore_progress - TOW_GAP_M, true)
        offender_distance_m = restore_progress - TOW_GAP_M
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
        _note_tow_hold("traffic signal or pedestrian crossing")
        tow_vehicle.speed_mps = 0.0
        return
    # Probe several intermediate footprints, including corners, BEFORE
    # advancing either collision body; nothing may overlap an actor or prop.
    var samples: int = maxi(1, int(ceil(travel / TOW_SWEEP_STEP_M)))
    for index in range(1, samples + 1):
        var candidate_progress: float = tow_progress_m + travel * float(index) / float(samples)
        var tow_pose: Transform3D = _tow_pose(candidate_progress, false)
        var offender_pose: Transform3D = _tow_pose(candidate_progress - TOW_GAP_M, true)
        if tow_vehicle.footprint_blocked_at(tow_pose):
            _note_tow_hold("tow-truck route physically occupied")
            tow_vehicle.speed_mps = 0.0
            return
        if offender.footprint_blocked_at(offender_pose):
            _note_tow_hold("offender route physically occupied")
            tow_vehicle.speed_mps = 0.0
            return
    _tow_hold_frames = 0
    _tow_hold_reason = ""
    tow_progress_m += travel
    tow_vehicle.global_transform = _tow_pose(tow_progress_m, false)
    offender.global_transform = _tow_pose(tow_progress_m - TOW_GAP_M, true)
    offender_distance_m = tow_progress_m - TOW_GAP_M
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

## Keep collision and signal rules authoritative, but identify what
## actually prevents service movement rather than silently waiting forever.
func _note_tow_hold(reason: String) -> void:
    if _tow_hold_reason != reason:
        _tow_hold_reason = reason
        _tow_hold_frames = 0
    _tow_hold_frames += 1
    # A sustained physical blockage triggers visible municipal vertical
    # recovery. No car is moved horizontally through another road user.
    if _tow_hold_frames >= SERVICE_HOLD_BEFORE_LIFT_FRAMES and service_lift_height_m == 0.0:
        if tow_started and not tow_completed and is_instance_valid(tow_vehicle) and is_instance_valid(offender):
            if tow_vehicle.people_clear_at(tow_vehicle.global_transform) and offender.people_clear_at(offender.global_transform):
                service_lift_height_m = 0.001
                _announce("Tow route blocked. Municipal crane lifting both vehicles clear.")
                return
    if _tow_hold_frames == 180 or (_tow_hold_frames > 180 and _tow_hold_frames % 600 == 0):
        _announce("Tow delayed: %s. Keep the route and crossing clear." % reason)
        print("CIVIC_TOW_HOLD reason=%s progress=%.2f/%.2f queue=%d released=%d tick=%d" % [
            reason, tow_progress_m, _tow_route_length(), stopped_count, released_ids.size(), tick])

## Last-resort on-site recovery for city traffic gridlock: an animated
## vertical lift keeps the actual vehicles present until they clear the road.
func _advance_service_lift(delta: float) -> void:
    if not is_instance_valid(tow_vehicle) or not is_instance_valid(offender):
        return
    service_lift_height_m = minf(SERVICE_LIFT_HEIGHT_M,
        service_lift_height_m + SERVICE_LIFT_SPEED_MPS * delta)
    tow_vehicle.global_transform = _tow_pose(tow_progress_m, false).translated(
        Vector3.UP * service_lift_height_m)
    offender.global_transform = _tow_pose(tow_progress_m - TOW_GAP_M, true).translated(
        Vector3.UP * service_lift_height_m)
    _update_tow_link()
    if service_lift_height_m >= SERVICE_LIFT_HEIGHT_M:
        tow_recovered_on_site = true
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
    if not tow_recovered_on_site and tow_progress_m < _tow_route_length() - 0.01:
        return
    # Store the canonical route endpoint, not the last incremental floating
    # point sample. Towing can end within 1 cm of that endpoint.
    if not tow_recovered_on_site:
        tow_progress_m = _tow_route_length()
    offender_distance_m = tow_progress_m - TOW_GAP_M
    tow_completed = true
    blocker_removed = true
    if is_instance_valid(tow_vehicle):
        tow_vehicle.queue_free()
    if is_instance_valid(offender):
        offender.queue_free()
    if is_instance_valid(tow_cable):
        tow_cable.queue_free()
    _announce("Municipal crane cleared the obstruction. Watch actual traffic recover." if tow_recovered_on_site else "Municipal tow reached the legal exit. Watch actual traffic recover.")

func _create_marshal() -> void:
    marshal = Node3D.new()
    marshal.name = "TrafficMarshal"
    marshal.position = Vector3(-19.5, 0.0, -8.0)
    add_child(marshal)
    CharacterArt.build(marshal, Color(0.82, 0.64, 0.20), Color(0.68, 0.46, 0.32),
        Color(0.19, 0.25, 0.30), Color(0.16, 0.20, 0.22))
    var caption := Label3D.new()
    caption.text = "TRAFFIC MARSHAL"
    caption.position.y = 2.1
    caption.font_size = 44
    caption.pixel_size = 0.006
    marshal.add_child(caption)
    var speech := Label3D.new()
    speech.name = "MarshalSpeech"
    speech.text = "Keep the footpath clear."
    speech.font_size = 36
    speech.pixel_size = 0.005
    speech.position = Vector3(0, 2.58, 0)
    marshal.add_child(speech)

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
    if is_instance_valid(marshal):
        var bubble := marshal.get_node_or_null("MarshalSpeech") as Label3D
        if bubble != null:
            bubble.text = message.substr(0, 88)
    feedback_changed.emit(message)


## GAME-015: a non-destructive stalled-service warning. Red lights or real
## obstacles may delay towing, but they must never silently fail the mission.
## Only a deliberate player choice reloads a save or restarts the level.
func _update_recovery_watchdog() -> void:
    if reported_tick < 0 or finished:
        _last_progress_tick = tick
        _last_progress_signature = ""
        _stalled = false
        return
    # Only real service stages and measurable tow/release progress reset
    # the clock; stopped-queue fluctuations alone do not hide a deadlock.
    var signature: String = "%d:%d:%d:%d:%d:%d" % [
        int(is_instance_valid(marshal)), int(intervention_tick >= 0),
        int(tow_started), int(tow_completed), int(roundf(tow_progress_m * 2.0)),
        released_ids.size()
    ]
    if _last_progress_tick < 0 or signature != _last_progress_signature:
        var had_stalled: bool = _stalled
        _last_progress_signature = signature
        _last_progress_tick = tick
        _stalled = false
        if had_stalled:
            _announce("Service is moving again. Keep the road clear while the team works.")
    elif not _stalled and tick - _last_progress_tick >= RECOVERY_STALL_TICKS:
        _stalled = true
        _announce("Service delayed: an obstacle or traffic is preventing progress. Reload a checkpoint or restart the level.")

func recovery_help_needed() -> bool:
    return _stalled and not finished and reported_tick >= 0

func guidance_state() -> Dictionary:
    var objective: String = "Watch the wrong-way car until two real vehicles queue."
    var has_target: bool = true
    var speaker: String = "Neighborhood Radio"
    if finished:
        objective = "Civic mission complete. The west approach is moving again."
        has_target = false
        speaker = "Traffic Marshal"
    elif blocker_removed:
        objective = "Watch for actual cars to resume; recovery is not confirmed yet."
        has_target = false
        speaker = "Traffic Marshal"
    elif tow_started:
        objective = "Keep the road clear as the municipal tow convoy reaches the legal exit."
        has_target = false
        speaker = "Traffic Marshal"
    elif intervention_tick >= 0:
        objective = "Wait on the sidewalk while the marshal arranges vehicle removal."
        has_target = false
        speaker = "Traffic Marshal"
    elif reported_tick >= 0:
        objective = "Report received. Wait safely for the marshal to arrive."
        has_target = false
    elif inspected:
        objective = "At the yellow post, choose Report to Municipal Service."
    elif stopped_count >= REQUIRED_STOPPED:
        objective = "At the yellow post, inspect the real queue and wrong-way driver."
    return {
        "title": "Wrong Way, Wrong Day",
        "objective": objective,
        "target": marker.global_position if is_instance_valid(marker) else Vector3.ZERO,
        "has_target": has_target and is_instance_valid(marker),
        "speaker": speaker,
        "dialogue": feedback,
        "recovery_available": recovery_help_needed(),
        "recovery_reason": "No service/traffic progress for about 30 seconds. Retry from a saved checkpoint or restart the entire level."
    }

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

## GAME-014: stable logical IDs, never ObjectDB instance IDs, are written to disk.
## A follower's queue history is stored by its index in the fixed convoy list.
func snapshot() -> Dictionary:
    var saved_followers: Array[Dictionary] = []
    for index in range(followers.size()):
        var car: CivicVehicleAgent = followers[index]
        var id: int = car.get_instance_id()
        saved_followers.append({
            "route_index": car.current_route_index,
            "distance": car.lane_distance_m,
            "speed": car.speed_mps,
            "target_speed": car.target_speed_mps,
            "active": car.active,
            "moved": moved_ids.has(id),
            "released": released_ids.has(id),
            "starting_distance": float(starting_distances.get(id, 0.0))
        })
    var marshal_progress: float = 0.0
    if is_instance_valid(marshal):
        marshal_progress = clampf((marshal.position.z + 8.0) / 3.7, 0.0, 1.0)
    return {
        "schema_version": CHECKPOINT_VERSION,
        "incident_id": incident_id,
        "approach_lane_id": approach_lane_id,
        "exit_lane_id": exit_lane_id,
        "tick": tick,
        "inspected": inspected,
        "reported_tick": reported_tick,
        "intervention_tick": intervention_tick,
        "marshal_present": is_instance_valid(marshal),
        "marshal_progress": marshal_progress,
        "offender_distance": offender_distance_m,
        "tow_started": tow_started,
        "tow_completed": tow_completed,
        "tow_recovered_on_site": tow_recovered_on_site,
        "service_lift_height": service_lift_height_m,
        "tow_progress": tow_progress_m,
        "blocker_removed": blocker_removed,
        "finished": finished,
        "peak_stopped": peak_stopped,
        "recovery_streak": recovery_streak,
        "feedback": feedback,
        "followers": saved_followers
    }

## Pure input preflight. Can be called before the gameplay session or any
## vehicle has been moved; a bad save cannot mutate live world state.
static func checkpoint_valid(raw: Variant, graph: CivicRoadGraph, civic: Variant, failures: Array = []) -> bool:
    if not (raw is Dictionary) or graph == null or not (civic is Dictionary):
        return _checkpoint_rejected("CKP-01: if not (raw is Dictionary) or graph == null or not (civic is Dictionary):", failures)
    var data: Dictionary = raw
    var session_data: Dictionary = civic
    if not _whole(data.get("schema_version"), CHECKPOINT_VERSION, CHECKPOINT_VERSION):
        return _checkpoint_rejected("CKP-02: if not _whole(data.get(\"schema_version\"), CHECKPOINT_VERSION, CHECKPOINT_VERSION):", failures)
    for key in ["incident_id", "approach_lane_id", "exit_lane_id", "tick", "reported_tick", "intervention_tick",
        "peak_stopped", "recovery_streak"]:
        if not _whole(data.get(key), -1, 1000000000):
            return _checkpoint_rejected("CKP-03: if not _whole(data.get(key), -1, 1000000000):", failures)
    var tick_value: int = int(data["tick"])
    if int(data["incident_id"]) < 1 or int(data["tick"]) < 0:
        return _checkpoint_rejected("CKP-04: if int(data[\"incident_id\"]) < 1 or int(data[\"tick\"]) < 0:", failures)
    for stamp in ["reported_tick", "intervention_tick"]:
        if int(data[stamp]) > tick_value:
            return _checkpoint_rejected("CKP-05: if int(data[stamp]) > tick_value:", failures)
    if int(data["intervention_tick"]) >= 0 and int(data["reported_tick"]) < 0:
        return _checkpoint_rejected("CKP-06: if int(data[\"intervention_tick\"]) >= 0 and int(data[\"reported_tick\"]) < 0:", failures)
    for flag in ["inspected", "marshal_present", "tow_started", "tow_completed", "blocker_removed", "finished"]:
        if not (data.get(flag) is bool):
            return _checkpoint_rejected("CKP-07: if not (data.get(flag) is bool):", failures)
    if not (data.get("feedback") is String):
        return _checkpoint_rejected("CKP-08: if not (data.get(\"feedback\") is String):", failures)
    if not _finite_range(data.get("marshal_progress"), 0.0, 1.0):
        return _checkpoint_rejected("CKP-09: if not _finite_range(data.get(\"marshal_progress\"), 0.0, 1.0):", failures)
    if not _finite_range(data.get("tow_progress"), 0.0, 500.0):
        return _checkpoint_rejected("CKP-10: if not _finite_range(data.get(\"tow_progress\"), 0.0, 500.0):", failures)
    if not _finite_range(data.get("offender_distance"), 0.0, 500.0):
        return _checkpoint_rejected("CKP-11: if not _finite_range(data.get(\"offender_distance\"), 0.0, 500.0):", failures)
    if not (data.get("followers") is Array) or data["followers"].size() != 4:
        return _checkpoint_rejected("CKP-12: if not (data.get(\"followers\") is Array) or data[\"followers\"].size() != 4:", failures)
    var inbound: CivicLaneData = graph.get_lane(int(data["approach_lane_id"]))
    var outbound: CivicLaneData = graph.get_lane(int(data["exit_lane_id"]))
    if inbound == null or outbound == null or not graph.outgoing_legal_lanes(inbound.lane_id, 1).has(outbound.lane_id):
        return _checkpoint_rejected("CKP-13: if inbound == null or outbound == null or not graph.outgoing_legal_lanes(inbound.lane_id, 1).has(outbound.lane_id):", failures)
    if inbound.centerline[0].distance_to(Vector3(-46, 0, 0)) > 0.1 or outbound.centerline[outbound.centerline.size() - 1].distance_to(Vector3(46, 0, 0)) > 0.1:
        return _checkpoint_rejected("CKP-14: if inbound.centerline[0].distance_to(Vector3(-46, 0, 0)) > 0.1 or outbound.centerline[outbound.centerline.size() - 1].distance_to(Vector3(46, 0, 0)) > 0.1:", failures)
    var total_length: float = inbound.length_m() + outbound.length_m()
    if float(data["offender_distance"]) > total_length + CHECKPOINT_DISTANCE_EPS_M or float(data["tow_progress"]) > total_length + CHECKPOINT_DISTANCE_EPS_M:
        return _checkpoint_rejected("CKP-15: if float(data[\"offender_distance\"]) > total_length + CHECKPOINT_DISTANCE_EPS_M or float(data[\"tow_progress\"]) > total_length + CHECKPOINT_DISTANCE_EPS_M:", failures)
    if int(data["peak_stopped"]) > data["followers"].size() or int(data["recovery_streak"]) > RECOVERY_FRAMES:
        return _checkpoint_rejected("CKP-16: if int(data[\"peak_stopped\"]) > data[\"followers\"].size() or int(data[\"recovery_streak\"]) > RECOVERY_FRAMES:", failures)
    # Inspection without reporting is allowed; the inverse is not.
    if int(data["reported_tick"]) >= 0 and not bool(data["inspected"]):
        return _checkpoint_rejected("CKP-17: if int(data[\"reported_tick\"]) >= 0 and not bool(data[\"inspected\"]):", failures)
    if bool(data["marshal_present"]) and int(data["reported_tick"]) < 0:
        return _checkpoint_rejected("CKP-18: if bool(data[\"marshal_present\"]) and int(data[\"reported_tick\"]) < 0:", failures)
    if bool(data["tow_started"]) and (int(data["intervention_tick"]) < 0 or not bool(data["marshal_present"])):
        return _checkpoint_rejected("CKP-19: if bool(data[\"tow_started\"]) and (int(data[\"intervention_tick\"]) < 0 or not bool(data[\"marshal_present\"])):", failures)
    if bool(data["tow_completed"]) and not bool(data["tow_started"]):
        return _checkpoint_rejected("CKP-20: if bool(data[\"tow_completed\"]) and not bool(data[\"tow_started\"]):", failures)
    if bool(data["blocker_removed"]) != bool(data["tow_completed"]):
        return _checkpoint_rejected("CKP-21: if bool(data[\"blocker_removed\"]) != bool(data[\"tow_completed\"]):", failures)
    if bool(data["finished"]) and not bool(data["tow_completed"]):
        return _checkpoint_rejected("CKP-22: if bool(data[\"finished\"]) and not bool(data[\"tow_completed\"]):", failures)
    if not (data.get("tow_recovered_on_site", false) is bool):
        return _checkpoint_rejected("invalid_recovery_flag", failures)
    if not _finite_range(data.get("service_lift_height", 0.0), 0.0, SERVICE_LIFT_HEIGHT_M):
        return _checkpoint_rejected("invalid_recovery_height", failures)
    if bool(data.get("tow_recovered_on_site", false)) and not bool(data["tow_completed"]):
        return _checkpoint_rejected("recovery_without_completed_tow", failures)
    if float(data.get("service_lift_height", 0.0)) > 0.0 and not bool(data["tow_started"]):
        return _checkpoint_rejected("lifting_without_tow", failures)
    if bool(data["tow_started"]):
        if float(data["tow_progress"]) < OFFENDER_DISTANCE + TOW_GAP_M or float(data["tow_progress"]) > total_length + CHECKPOINT_DISTANCE_EPS_M:
            return _checkpoint_rejected("CKP-23: if float(data[\"tow_progress\"]) < OFFENDER_DISTANCE + TOW_GAP_M or float(data[\"tow_progress\"]) > total_length:", failures)
        if bool(data["tow_completed"]) and not bool(data.get("tow_recovered_on_site", false)) and float(data["tow_progress"]) < total_length - CHECKPOINT_DISTANCE_EPS_M:
            return _checkpoint_rejected("CKP-24: if bool(data[\"tow_completed\"]) and float(data[\"tow_progress\"]) < total_length - CHECKPOINT_DISTANCE_EPS_M:", failures)
    elif float(data["tow_progress"]) != 0.0:
        return _checkpoint_rejected("CKP-25: elif float(data[\"tow_progress\"]) != 0.0:", failures)
    if not (session_data.get("incidents") is Dictionary) or not (session_data.get("missions") is Dictionary):
        return _checkpoint_rejected("CKP-26: if not (session_data.get(\"incidents\") is Dictionary) or not (session_data.get(\"missions\") is Dictionary):", failures)
    var incident_state: CivicIncidentManager = CivicIncidentManager.from_json(JSON.stringify(session_data["incidents"]))
    var mission_state := CivicMissionManager.new()
    if incident_state == null or not mission_state.restore(session_data["missions"]):
        return _checkpoint_rejected("CKP-27: if incident_state == null or not mission_state.restore(session_data[\"missions\"]):", failures)
    if not incident_state.incidents.has(int(data["incident_id"])) or not mission_state.missions.has(MISSION_ID):
        return _checkpoint_rejected("CKP-28: if not incident_state.incidents.has(int(data[\"incident_id\"])) or not mission_state.missions.has(MISSION_ID):", failures)
    var saved_incident: Dictionary = incident_state.incidents[int(data["incident_id"])]
    if saved_incident.get("kind") != "wrong_way_driving" or saved_incident.get("location_key") != "market_west_approach":
        return _checkpoint_rejected("CKP-29: if saved_incident.get(\"kind\") != \"wrong_way_driving\" or saved_incident.get(\"location_key\") != \"market_west_approach\":", failures)
    # Completed incidents keep their original last tick while later civic
    # missions advance the shared manager. Only an ACTIVE wrong-way incident
    # must be current with the global timeline.
    if tick_value < incident_state.current_tick and not bool(data["finished"]):
        return _checkpoint_rejected("CKP-30: active_wrong_way_snapshot_older_than_civic_clock", failures)
    var mission: Dictionary = mission_state.missions[MISSION_ID]
    var progress: Dictionary = mission["progress"]
    for objective in ["congestion_observed", "incident_reported", "marshal_intervened", "sustained_recovery"]:
        if not progress.has(objective) or not _whole(progress[objective], 0, 1):
            return _checkpoint_rejected("CKP-31: if not progress.has(objective) or not _whole(progress[objective], 0, 1):", failures)
    if bool(data["inspected"]) != (int(progress["congestion_observed"]) == 1):
        return _checkpoint_rejected("CKP-32: if bool(data[\"inspected\"]) != (int(progress[\"congestion_observed\"]) == 1):", failures)
    if (int(data["reported_tick"]) >= 0) != (int(progress["incident_reported"]) == 1):
        return _checkpoint_rejected("CKP-33: if (int(data[\"reported_tick\"]) >= 0) != (int(progress[\"incident_reported\"]) == 1):", failures)
    if (int(data["intervention_tick"]) >= 0) != (int(progress["marshal_intervened"]) == 1):
        return _checkpoint_rejected("CKP-34: if (int(data[\"intervention_tick\"]) >= 0) != (int(progress[\"marshal_intervened\"]) == 1):", failures)
    if bool(data["finished"]) != (int(progress["sustained_recovery"]) == 1):
        return _checkpoint_rejected("CKP-35: if bool(data[\"finished\"]) != (int(progress[\"sustained_recovery\"]) == 1):", failures)
    var current_state: String = str(saved_incident.get("state", ""))
    if bool(data["finished"]):
        if current_state != CivicIncidentManager.RESOLVED or mission["state"] != CivicMissionManager.COMPLETED or not mission_state.rewarded.has(MISSION_ID):
            return _checkpoint_rejected("CKP-36: if current_state != CivicIncidentManager.RESOLVED or mission[\"state\"] != CivicMissionManager.COMPLETED or not mission_state.rewarded.has(MISSION_ID):", failures)
    elif int(data["intervention_tick"]) >= 0:
        if current_state != CivicIncidentManager.INTERVENTION:
            return _checkpoint_rejected("CKP-37: if current_state != CivicIncidentManager.INTERVENTION:", failures)
    elif int(data["reported_tick"]) >= 0:
        if current_state != CivicIncidentManager.ESCALATED:
            return _checkpoint_rejected("CKP-38: if current_state != CivicIncidentManager.ESCALATED:", failures)
    elif current_state != CivicIncidentManager.ACTIVE:
        return _checkpoint_rejected("CKP-39: elif current_state != CivicIncidentManager.ACTIVE:", failures)
    var calculated_stops: int = 0
    for item in data["followers"]:
        if not (item is Dictionary):
            return _checkpoint_rejected("CKP-40: if not (item is Dictionary):", failures)
        for flag in ["active", "moved", "released"]:
            if not (item.get(flag) is bool):
                return _checkpoint_rejected("CKP-41: if not (item.get(flag) is bool):", failures)
        if not _whole(item.get("route_index"), 0, 1):
            return _checkpoint_rejected("CKP-42: if not _whole(item.get(\"route_index\"), 0, 1):", failures)
        var segment: CivicLaneData = inbound if int(item["route_index"]) == 0 else outbound
        if not _finite_range(item.get("distance"), 0.0, segment.length_m() + CHECKPOINT_DISTANCE_EPS_M):
            return _checkpoint_rejected("CKP-43: if not _finite_range(item.get(\"distance\"), 0.0, segment.length_m() + CHECKPOINT_DISTANCE_EPS_M):", failures)
        for speed_key in ["speed", "target_speed"]:
            if not _finite_range(item.get(speed_key), 0.0, 45.0):
                return _checkpoint_rejected("CKP-44: if not _finite_range(item.get(speed_key), 0.0, 45.0):", failures)
        if not _finite_range(item.get("starting_distance"), 0.0, inbound.length_m()):
            return _checkpoint_rejected("CKP-45: if not _finite_range(item.get(\"starting_distance\"), 0.0, inbound.length_m()):", failures)
        if bool(item["released"]) and not bool(item["moved"]):
            return _checkpoint_rejected("CKP-46: if bool(item[\"released\"]) and not bool(item[\"moved\"]):", failures)
        if not bool(item["active"]) and float(item["speed"]) != 0.0:
            return _checkpoint_rejected("CKP-47: if not bool(item[\"active\"]) and float(item[\"speed\"]) != 0.0:", failures)
        if bool(item["active"]) and bool(item["moved"]) and int(item["route_index"]) == 0 and float(item["distance"]) <= OFFENDER_DISTANCE + 6.0 and float(item["speed"]) < 0.35:
            calculated_stops += 1
    if calculated_stops > int(data["peak_stopped"]):
        return _checkpoint_rejected("CKP-48: if calculated_stops > int(data[\"peak_stopped\"]):", failures)
    return true

## Optional reason collector for regression reports. Expected invalid saves
## remain quiet; only callers requesting diagnostics receive the exact gate.
static func _checkpoint_rejected(reason: String, failures: Array) -> bool:
    failures.append(reason)
    return false

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
    if not (value is int or value is float):
        return false
    var number: float = float(value)
    return is_finite(number) and number >= minimum and number <= maximum and number == floorf(number)

static func _finite_range(value: Variant, minimum: float, maximum: float) -> bool:
    if not (value is int or value is float):
        return false
    var number: float = float(value)
    return is_finite(number) and number >= minimum and number <= maximum

## Recreate physical staging without registering or overwriting any civic
## manager state. Called only after checkpoint_valid has succeeded.
func prepare_restore(world: Node3D, actor: Node3D, graph: CivicRoadGraph, civic_session: CivicGameplaySession, spawner: CivicTrafficSpawner = null) -> bool:
    if incident_id >= 0 or not is_inside_tree() or graph == null or civic_session == null or actor == null:
        return false
    player = actor
    session = civic_session
    city_graph = graph
    traffic_system = spawner
    if not _find_approach() or not _stage_vehicles():
        _clear_staging()
        return false
    marker = ReportPoint.new() as CivicWrongWayReportMarker
    marker.name = "WrongWayEvidencePoint"
    marker.position = Vector3(-20.0, 0.2, -5.3)
    add_child(marker)
    marker.activated.connect(_on_marker_activated)
    return true

## Preserve existing actors on same-scene F9. A fresh scene uses
## prepare_restore first, then restores the validated mission checkpoint.
func restore(raw: Variant) -> bool:
    if not checkpoint_valid(raw, city_graph, session.snapshot()):
        return false
    var data: Dictionary = raw
    if not [ -1, int(data["incident_id"]) ].has(incident_id):
        return false
    if approach_lane_id != int(data["approach_lane_id"]) or exit_lane_id != int(data["exit_lane_id"]):
        return false
    if followers.size() != data["followers"].size():
        return false
    if not bool(data["tow_completed"]) and not is_instance_valid(offender):
        # A completed scene cannot be rewound in place after its collider
        # was deleted. Reject before mutating missions or actor positions.
        return false
    tick = int(data["tick"])
    incident_id = int(data["incident_id"])
    inspected = data["inspected"]
    reported_tick = int(data["reported_tick"])
    intervention_tick = int(data["intervention_tick"])
    peak_stopped = int(data["peak_stopped"])
    tow_recovered_on_site = bool(data.get("tow_recovered_on_site", false))
    service_lift_height_m = float(data.get("service_lift_height", 0.0))
    recovery_streak = int(data["recovery_streak"])
    feedback = data["feedback"]
    moved_ids.clear()
    released_ids.clear()
    starting_distances.clear()
    for index in range(followers.size()):
        var car: CivicVehicleAgent = followers[index]
        var record: Dictionary = data["followers"][index]
        car.current_route_index = int(record["route_index"])
        car.lane_distance_m = float(record["distance"])
        car.speed_mps = float(record["speed"])
        car.target_speed_mps = float(record["target_speed"])
        car.active = bool(record["active"])
        car.clear_lead_observation()
        car._place_on_lane()
        var id: int = car.get_instance_id()
        starting_distances[id] = float(record["starting_distance"])
        if bool(record["moved"]):
            moved_ids[id] = true
        if bool(record["released"]):
            released_ids[id] = true
    stopped_count = _actual_stopped_count()
    if bool(data["marshal_present"]):
        if not is_instance_valid(marshal):
            _create_marshal()
        marshal.position = Vector3(-19.5, 0.0, -8.0 + 3.7 * float(data["marshal_progress"]))
    elif is_instance_valid(marshal):
        marshal.queue_free()
        marshal = null
    tow_started = false
    tow_completed = false
    blocker_removed = false
    if is_instance_valid(tow_vehicle):
        remove_child(tow_vehicle)
        tow_vehicle.queue_free()
        tow_vehicle = null
    if is_instance_valid(tow_cable):
        remove_child(tow_cable)
        tow_cable.queue_free()
        tow_cable = null
    tow_progress_m = 0.0
    if bool(data["tow_started"]):
        if bool(data["tow_completed"]):
            tow_started = true
            tow_completed = true
            blocker_removed = true
            tow_progress_m = float(data["tow_progress"])
            if is_instance_valid(offender):
                offender.queue_free()
                offender = null
        else:
            if not _start_tow_convoy(float(data["tow_progress"])):
                return false
            if service_lift_height_m > 0.0:
                tow_vehicle.global_transform = _tow_pose(tow_progress_m, false).translated(
                    Vector3.UP * service_lift_height_m)
                offender.global_transform = _tow_pose(tow_progress_m - TOW_GAP_M, true).translated(
                    Vector3.UP * service_lift_height_m)
                _update_tow_link()
    else:
        if is_instance_valid(offender):
            _place_offender(float(data["offender_distance"]))
        else:
            # Finished worlds cannot be rewound into an unsafe active phase
            # without a new scene; this is the only rejected rewind case.
            return false
    finished = bool(data["finished"])
    if finished and is_instance_valid(marker):
        marker.queue_free()
    return true
