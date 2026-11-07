class_name CivicIllegalParkingMission
extends Node3D
## GAME-016: real static vehicle obstruction, physical pedestrian stop and
## cooperative owner relocation. No synthetic pedestrian throughput scores.
signal incident_card_requested(state: Dictionary)
signal feedback_changed(message: String)
signal mission_completed

const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const OwnerScene = preload("res://scripts/civic/parking_owner.gd")
const MISSION_ID: String = "market_illegal_parking"
const VEHICLE_START: Vector3 = Vector3(24.0, 0.0, -5.0)
const OWNER_START: Vector3 = Vector3(20.0, 0.0, -7.5)
const OWNER_DESTINATION: Vector3 = Vector3(22.0, 0.0, -7.5)
const WALK_START: Vector3 = Vector3(19.0, 0.0, -5.0)
const WALK_END_X: float = 32.0
const CLEARANCE_X: float = 27.0
const PARKING_BAY: Vector3 = Vector3(36.0, 0.0, -8.5)
const PEDESTRIAN_SPEED: float = 1.6
const OWNER_SPEED: float = 1.35
const CAR_SPEED: float = 1.5
const BLOCKED_FRAMES_REQUIRED: int = 10
const MAX_INTERACTION_DISTANCE: float = 3.0

var session: CivicGameplaySession
var player: Node3D
var owner: CivicParkingOwner
var parked_vehicle: CivicVehicleAgent
var witness: AnimatableBody3D
var incident_id: int = -1
var tick: int = 0
var blocking_frames: int = 0
var observed_blockage: bool = false
var inspected: bool = false
var requested_tick: int = -1
var intervention_tick: int = -1
var relocation_started: bool = false
var relocation_complete: bool = false
var pedestrian_recovered: bool = false
var finished: bool = false
var owner_agreed: bool = false
var feedback: String = "Find the illegally parked car blocking the north footpath."
var _parking_route: PackedVector3Array = PackedVector3Array([
    VEHICLE_START, Vector3(24.0, 0.0, -8.5), PARKING_BAY
])
var _parking_segment: int = 0
var _walking_distance: float = 0.0
var _walking_before_block: bool = false
var _clearance_frames: int = 0

func _init() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(world: Node3D, actor: Node3D, civic_session: CivicGameplaySession) -> bool:
    if world == null or actor == null or civic_session == null or incident_id >= 0 or not is_inside_tree():
        return false
    session = civic_session
    player = actor
    tick = maxi(session.tick, session.incidents.current_tick)
    # The physical car exists before registering anything in mission systems.
    parked_vehicle = VehicleScene.instantiate() as CivicVehicleAgent
    if parked_vehicle == null:
        return false
    parked_vehicle.name = "IllegallyParkedCar"
    add_child(parked_vehicle)
    parked_vehicle.position = VEHICLE_START
    parked_vehicle.rotation.y = -PI * 0.5
    var visual := parked_vehicle.get_node_or_null("Visual") as MeshInstance3D
    if visual != null:
        var finish := StandardMaterial3D.new()
        finish.albedo_color = Color(0.90, 0.24, 0.08)
        visual.material_override = finish
    var car_label := Label3D.new()
    car_label.name = "IllegalParkingLabel"
    car_label.text = "NO PARKING ON FOOTPATH"
    car_label.position = Vector3(0, 2.4, 0)
    car_label.font_size = 40
    car_label.pixel_size = 0.006
    parked_vehicle.add_child(car_label)

    owner = OwnerScene.new() as CivicParkingOwner
    owner.name = "ParkingOwner"
    add_child(owner)
    owner.position = OWNER_START
    owner.activated.connect(_on_owner_activated)

    witness = AnimatableBody3D.new()
    witness.name = "FootpathWitness"
    witness.collision_layer = 8
    witness.collision_mask = 0
    witness.sync_to_physics = false
    witness.position = WALK_START
    var witness_collider := CollisionShape3D.new()
    witness_collider.name = "CollisionShape3D"
    var witness_shape := CapsuleShape3D.new()
    witness_shape.radius = 0.34
    witness_shape.height = 1.70
    witness_collider.shape = witness_shape
    witness_collider.position.y = 0.9
    witness.add_child(witness_collider)
    var witness_visual := MeshInstance3D.new()
    witness_visual.name = "PedestrianVisual"
    var witness_mesh := CapsuleMesh.new()
    witness_mesh.radius = 0.33
    witness_mesh.height = 1.7
    witness_visual.mesh = witness_mesh
    witness_visual.position.y = 0.9
    var pedestrian_paint := StandardMaterial3D.new()
    pedestrian_paint.albedo_color = Color(0.34, 0.76, 0.45)
    witness_visual.material_override = pedestrian_paint
    witness.add_child(witness_visual)
    add_child(witness)

    # A marked destination is not a fake relocation: the car must physically
    # travel and its solid collider must finish inside this indicated bay.
    var bay := MeshInstance3D.new()
    bay.name = "RelocationBay"
    bay.position = PARKING_BAY + Vector3(0, 0.03, 0)
    var pad := BoxMesh.new()
    pad.size = Vector3(5.0, 0.04, 3.4)
    bay.mesh = pad
    var pad_paint := StandardMaterial3D.new()
    pad_paint.albedo_color = Color(0.22, 0.50, 0.28, 0.55)
    pad_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bay.material_override = pad_paint
    add_child(bay)
    var incident: Dictionary = session.incidents.create_incident("illegal_parking", 1601, tick, "market_east_north_footpath")
    if not bool(incident.get("ok", false)):
        queue_free()
        return false
    incident_id = int(incident["id"])
    var registered: bool = session.missions.register_mission({
        "id": MISSION_ID, "reward": 75, "objectives": [
            {"event": "pedestrian_block_observed", "target": 1},
            {"event": "owner_contacted", "target": 1},
            {"event": "vehicle_relocated", "target": 1},
            {"event": "pedestrian_route_recovered", "target": 1}
        ]
    })
    if not registered or not session.missions.start(MISSION_ID):
        push_error("Parking civic objective registration failed")
        return false
    _say("New incident: a driver has parked over the footpath. Watch the pedestrian and speak with the owner.")
    return true

func _physics_process(delta: float) -> void:
    if incident_id < 0 or finished or delta <= 0.0:
        return
    tick += 1
    _advance_witness(delta)
    if requested_tick >= 0:
        _advance_owner_and_car(delta)
    if relocation_complete and not pedestrian_recovered:
        var clear: bool = not _path_blocked_by_parked_car(WALK_START + Vector3(5.0, 0, 0), WALK_START + Vector3(5.3, 0, 0))
        if clear and witness.position.x >= CLEARANCE_X:
            _clearance_frames += 1
        else:
            _clearance_frames = 0
        if _clearance_frames >= 8:
            _complete_recovery()

func _advance_witness(delta: float) -> void:
    if not is_instance_valid(witness) or witness.position.x >= WALK_END_X:
        return
    var candidate: Vector3 = witness.position + Vector3(minf(PEDESTRIAN_SPEED * delta, WALK_END_X - witness.position.x), 0, 0)
    if _pedestrian_path_clear(witness.position, candidate):
        witness.position = candidate
        _walking_distance = witness.position.x - WALK_START.x
        if _walking_distance >= 0.5:
            _walking_before_block = true
    else:
        if _walking_before_block and _path_blocked_by_parked_car(witness.position, candidate):
            blocking_frames += 1
            if blocking_frames >= BLOCKED_FRAMES_REQUIRED and not observed_blockage:
                observed_blockage = true
                _say("A pedestrian has been stopped by the actual parked car. Collect evidence with its owner.")

func _pedestrian_path_clear(start: Vector3, finish: Vector3) -> bool:
    var probe := SphereShape3D.new()
    probe.radius = 0.32
    var steps: int = maxi(1, int(ceil(start.distance_to(finish) / 0.15)))
    for index in range(1, steps + 1):
        var candidate: Vector3 = start.lerp(finish, float(index) / float(steps))
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = probe
        query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3(0, 0.94, 0))
        query.collision_mask = 1 | 2 | 4
        query.exclude = [witness.get_rid()]
        var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 16)
        for hit in hits:
            var obstacle: CollisionObject3D = hit.get("collider") as CollisionObject3D
            if obstacle == null or _is_walk_support(obstacle):
                continue
            return false
    return true

static func _is_walk_support(obstacle: CollisionObject3D) -> bool:
    # Only floor surfaces are ignored. Cars, walls, NPCs and street furniture
    # remain genuine obstructions to pedestrian movement.
    return obstacle.name == "TerrainGround" or obstacle.name.begins_with("Sidewalk") or obstacle.name.ends_with("Road")

func _path_blocked_by_parked_car(start: Vector3, finish: Vector3) -> bool:
    if not is_instance_valid(parked_vehicle) or not is_instance_valid(witness):
        return false
    var collider: CollisionObject3D = parked_vehicle.get_node_or_null("CollisionBody") as CollisionObject3D
    if collider == null:
        return false
    var probe := SphereShape3D.new()
    probe.radius = 0.33
    var steps: int = maxi(1, int(ceil(start.distance_to(finish) / 0.15)))
    for index in range(steps + 1):
        var candidate: Vector3 = start.lerp(finish, float(index) / float(steps))
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = probe
        query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3(0, 0.94, 0))
        query.collision_mask = 4
        query.exclude = [witness.get_rid()]
        var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 16)
        for hit in hits:
            if hit.get("collider") == collider:
                return true
    return false

func _on_owner_activated(actor: Node) -> void:
    if _can_interact(actor):
        incident_card_requested.emit(incident_card_state())
    else:
        _say("Talk to the owner from the sidewalk within three metres.")

func _can_interact(actor: Node) -> bool:
    if actor != player or finished or not is_instance_valid(owner):
        return false
    var distance_m: float = player.global_position.distance_to(owner.global_position)
    return bool(session.interactions.inspect(incident_id, distance_m).get("ok", false))

func incident_card_state() -> Dictionary:
    var phase: String = "Pedestrian obstruction not yet witnessed"
    if finished:
        phase = "Footpath reopened"
    elif relocation_complete:
        phase = "Owner parked safely; waiting for pedestrian to pass"
    elif relocation_started:
        phase = "Owner relocating the car safely"
    elif requested_tick >= 0:
        phase = "Owner agreed to relocate"
    elif inspected:
        phase = "Observed blockage documented"
    return {
        "title": "Illegal Parking | Footpath First",
        "location": "Market Chowk east north footpath",
        "evidence": "An orange car occupies the walking path. Witness blocked for %d physics frames." % blocking_frames,
        "phase": phase, "hint": feedback,
        "report_label": "Ask owner to relocate",
        "report_action": "request_owner",
        "can_inspect": observed_blockage and not inspected and not finished,
        "can_report": inspected and requested_tick < 0 and not finished,
        "reported": requested_tick >= 0,
        "finished": finished
    }

func perform_incident_action(actor: Node, action: String) -> bool:
    if not _can_interact(actor):
        _say("Owner interaction unavailable at this distance.")
        return false
    if action == "inspect":
        if not observed_blockage or inspected:
            _say("Watch the pedestrian encounter the parked car before inspecting.")
            return false
        if not session.missions.record_event(MISSION_ID, "pedestrian_block_observed"):
            return false
        inspected = true
        _say("Evidence recorded: the footpath is obstructed. Ask the owner to relocate.")
        return true
    if action != "request_owner" or not inspected or requested_tick >= 0:
        return false
    var distance_m: float = player.global_position.distance_to(owner.global_position)
    var permissions := PackedStringArray(["report"])
    if not session.interactions.begin_action(0, incident_id, "report", distance_m, permissions):
        return false
    var accepted: Dictionary = session.interactions.confirm(0, tick, distance_m, permissions)
    if not bool(accepted.get("ok", false)):
        return false
    if not session.missions.record_event(MISSION_ID, "owner_contacted"):
        return false
    requested_tick = tick
    owner_agreed = true
    _say("Owner: You're right. I'll move it to the marked bay; please keep the path clear.")
    return true

func _advance_owner_and_car(delta: float) -> void:
    if not relocation_started:
        if not is_instance_valid(owner):
            return
        owner.position = owner.position.move_toward(OWNER_DESTINATION, OWNER_SPEED * delta)
        if owner.position.distance_to(OWNER_DESTINATION) <= 0.12:
            if session.incidents.transition(incident_id, CivicIncidentManager.INTERVENTION, tick, "owner_accepted_safe_relocation"):
                intervention_tick = tick
                relocation_started = true
                _say("Owner reached the vehicle. Moving to a marked bay, away from the footpath.")
        return
    if relocation_complete or not is_instance_valid(parked_vehicle):
        return
    var remaining: float = CAR_SPEED * delta
    while remaining > 0.000001 and _parking_segment < _parking_route.size() - 1:
        var target: Vector3 = _parking_route[_parking_segment + 1]
        var car_position: Vector3 = parked_vehicle.position
        var vector: Vector3 = target - car_position
        if vector.length() <= 0.001:
            _parking_segment += 1
            continue
        var distance: float = minf(remaining, vector.length())
        var new_position: Vector3 = car_position + vector.normalized() * distance
        var yaw: float = atan2(-vector.normalized().x, -vector.normalized().z)
        var candidate_pose := Transform3D(Basis(Vector3.UP, yaw), new_position)
        if not _relocation_clear(parked_vehicle.global_transform, candidate_pose):
            return
        parked_vehicle.global_transform = candidate_pose
        remaining -= distance
        if parked_vehicle.position.distance_to(target) <= 0.001:
            _parking_segment += 1
    if _parking_segment >= _parking_route.size() - 1:
        relocation_complete = true
        if session.missions.record_event(MISSION_ID, "vehicle_relocated"):
            _say("Owner parked in the marked bay. Waiting for the pedestrian route to reopen.")

func _relocation_clear(from_pose: Transform3D, to_pose: Transform3D) -> bool:
    var body: StaticBody3D = parked_vehicle.get_node_or_null("CollisionBody") as StaticBody3D
    if body == null:
        return false
    var collider: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collider == null or collider.shape == null:
        return false
    var distance_m: float = from_pose.origin.distance_to(to_pose.origin)
    var samples: int = maxi(1, int(ceil(distance_m / 0.18)))
    for index in range(1, samples + 1):
        var fraction: float = float(index) / float(samples)
        var pose: Transform3D = from_pose.interpolate_with(to_pose, fraction)
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = collider.shape
        query.transform = pose * body.transform * collider.transform
        query.collision_mask = 1 | 2 | 4 | 8
        query.exclude = [body.get_rid()]
        var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 32)
        for hit in hits:
            var obstacle: CollisionObject3D = hit.get("collider") as CollisionObject3D
            if obstacle == null or _is_walk_support(obstacle):
                continue
            return false
    return true

func _complete_recovery() -> void:
    if finished or not relocation_complete or not is_instance_valid(witness):
        return
    if witness.position.x < CLEARANCE_X:
        return
    if not session.incidents.transition(incident_id, CivicIncidentManager.RESOLVED, tick, "actual_pedestrian_route_reopened"):
        return
    session.missions.record_event(MISSION_ID, "pedestrian_route_recovered")
    session.metrics.apply_outcome("parking:%d:reopened" % incident_id, tick,
        {"safety": 15, "trust": 20, "cooperation": 20}, "verified_pedestrian_recovery")
    var reward: int = session.missions.claim_reward(MISSION_ID)
    pedestrian_recovered = true
    finished = true
    _say("Path reopened: witness passed the old parking spot. Civic reward +%d." % reward)
    mission_completed.emit()

func guidance_state() -> Dictionary:
    var objective: String = "Watch the pedestrian stop behind the parked orange car."
    var target: Vector3 = VEHICLE_START
    var show: bool = true
    if finished:
        objective = "Footpath recovered. The illegal parking case is closed."
        show = false
    elif relocation_complete:
        objective = "Confirm the pedestrian passes the former blockage."
        show = false
    elif relocation_started:
        objective = "Give the moving vehicle space to reach the marked bay."
        show = false
    elif requested_tick >= 0:
        objective = "Owner agreed; wait safely for the relocation."
        show = false
    elif inspected:
        objective = "Return to the owner and ask for relocation."
        target = owner.global_position
    elif observed_blockage:
        objective = "Talk to the owner and choose Inspect Evidence."
        target = owner.global_position
    return {
        "title": "Footpath First | Illegal Parking",
        "objective": objective,
        "has_target": show,
        "target": target,
        "speaker": "Neighborhood Radio" if requested_tick < 0 else "Vehicle Owner",
        "dialogue": feedback,
        "recovery_available": false
    }

func _say(message: String) -> void:
    feedback = message
    feedback_changed.emit(message)
