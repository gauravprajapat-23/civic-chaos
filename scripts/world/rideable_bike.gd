class_name CivicRideableBike
extends StaticBody3D
## VEHICLE-RIDE-01: a physical-looking, reusable player motorcycle.
## Only the rider's collision-aware CharacterBody moves in ride mode;
## the interactable body is disabled while attached to that rider.
const MOUNT_DISTANCE_M: float = 2.8
## One authoritative collision envelope for full bike length, footpegs,
## rider and front/rear wheels. Bottom is above roadway surface, so the
## ground is not interpreted as a wall.
const FOOTPRINT_SIZE: Vector3 = Vector3(1.15, 1.55, 3.05)
const FOOTPRINT_CENTER: Vector3 = Vector3(0.0, 1.12, -0.05)
const FOOTPRINT_MARGIN: float = 0.035
var _footprint_shape: BoxShape3D
var _rider_sensing_body: StaticBody3D
var _rider_sensing_collision: CollisionShape3D
var rider: Node3D
var home_parent: Node
var _wheel_front: MeshInstance3D
var _wheel_rear: MeshInstance3D
var _ride_label: Label3D
var _visual_rig: Node3D
var _front_assembly: Node3D
const MAX_VISUAL_LEAN_RAD: float = 0.19
const MAX_FRONT_STEER_RAD: float = 0.38
var _headlamp: MeshInstance3D
var _brake_lamp: MeshInstance3D
var _wheel_roll_total: float = 0.0

func _ready() -> void:
    collision_layer = 16
    collision_mask = 0
    _visual_rig = Node3D.new()
    _visual_rig.name = "VisualRig"
    add_child(_visual_rig)
    _make_visuals()
    _footprint_shape = BoxShape3D.new()
    _footprint_shape.size = FOOTPRINT_SIZE

func _part(part_name: String, dimensions: Vector3, at: Vector3,
        color: Color) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = part_name
    var block := BoxMesh.new()
    block.size = dimensions
    mesh.mesh = block
    mesh.position = at
    var paint := StandardMaterial3D.new()
    paint.albedo_color = color
    paint.metallic = 0.18
    paint.roughness = 0.65
    mesh.material_override = paint
    _visual_rig.add_child(mesh)
    return mesh

func _wheel(part_name: String, at: Vector3) -> MeshInstance3D:
    var wheel := MeshInstance3D.new()
    wheel.name = part_name
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.43
    cylinder.bottom_radius = 0.43
    cylinder.height = 0.24
    wheel.mesh = cylinder
    wheel.position = at
    wheel.rotation.z = PI * 0.5
    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color(0.09, 0.11, 0.12)
    wheel.material_override = rubber
    _visual_rig.add_child(wheel)
    # A visible radial spoke makes the rolling direction readable.
    # The CylinderMesh axle is LOCAL Y (tilted onto the bike's X axis).
    # Children follow the wheel's LOCAL axial spin automatically.
    var spoke := MeshInstance3D.new()
    spoke.name = "RollingSpoke"
    var spoke_mesh := BoxMesh.new()
    spoke_mesh.size = Vector3(0.055, 0.27, 0.32)
    spoke.mesh = spoke_mesh
    spoke.position = Vector3(0.0, 0.0, -0.19)
    var spoke_paint := StandardMaterial3D.new()
    spoke_paint.albedo_color = Color(0.78, 0.82, 0.84)
    spoke.material_override = spoke_paint
    wheel.add_child(spoke)
    var ring := MeshInstance3D.new()
    ring.name = "WheelHub"
    var hub := CylinderMesh.new()
    hub.top_radius = 0.16
    hub.bottom_radius = 0.16
    hub.height = 0.265
    ring.mesh = hub
    ring.material_override = spoke_paint
    wheel.add_child(ring)
    for side in [-1.0, 1.0]:
        var disc := MeshInstance3D.new()
        disc.name = "BrakeDisc_%d" % int(side)
        var disc_mesh := CylinderMesh.new()
        disc_mesh.top_radius = 0.29
        disc_mesh.bottom_radius = 0.29
        disc_mesh.height = 0.016
        disc.mesh = disc_mesh
        disc.position.y = float(side) * 0.14
        disc.material_override = spoke_paint
        wheel.add_child(disc)
    return wheel

func _make_visuals() -> void:
    var shape := CollisionShape3D.new()
    shape.name = "InteractionShape"
    shape.position = Vector3(0, 0.85, 0)
    var box := BoxShape3D.new()
    box.size = Vector3(1.0, 1.35, 1.8)
    shape.shape = box
    add_child(shape)

    _wheel_front = _wheel("FrontWheel", Vector3(0, 0.43, -0.95))
    _wheel_rear = _wheel("RearWheel", Vector3(0, 0.43, 0.85))
    _part("Chassis", Vector3(0.26, 0.30, 1.62), Vector3(0, 0.84, 0),
        Color(0.12, 0.18, 0.24))
    _part("FuelTank", Vector3(0.58, 0.42, 0.82), Vector3(0, 1.10, -0.23),
        Color(0.83, 0.18, 0.13))
    _part("Seat", Vector3(0.56, 0.16, 0.82), Vector3(0, 1.18, 0.40),
        Color(0.09, 0.10, 0.12))
    _part("Fork", Vector3(0.14, 0.95, 0.14), Vector3(0, 0.89, -0.94),
        Color(0.64, 0.69, 0.71))
    _part("Handlebar", Vector3(0.95, 0.10, 0.14), Vector3(0, 1.53, -0.91),
        Color(0.20, 0.23, 0.25))
    _part("Headlight", Vector3(0.36, 0.27, 0.15), Vector3(0, 1.13, -1.05),
        Color(1.0, 0.94, 0.62))
    _brake_lamp = _part("TailLight", Vector3(0.40, 0.15, 0.12), Vector3(0, 0.98, 1.05),
        Color(1.0, 0.12, 0.07))
    _headlamp = _visual_rig.get_node_or_null("Headlight") as MeshInstance3D
    _enhance_motorcycle_body()
    _assemble_steering_fork()
    _ride_label = Label3D.new()
    _ride_label.name = "BikeHint"
    _ride_label.text = "BIKE\nE / USE TO RIDE"
    _ride_label.font_size = 38
    _ride_label.pixel_size = 0.006
    _ride_label.position = Vector3(0, 2.2, 0)
    add_child(_ride_label)

## Motorcycle-design pass: readable silhouette and details at mobile
## camera distance. All parts are purely visual, with zero physics bodies.
func _enhance_motorcycle_body() -> void:
    var steel := Color(0.58, 0.67, 0.71)
    var black := Color(0.10, 0.13, 0.15)
    var accent := Color(0.96, 0.43, 0.12)
    var dark_red := Color(0.54, 0.10, 0.10)
    _part("EngineBlock", Vector3(0.48, 0.51, 0.57), Vector3(0, 0.73, -0.03), steel)
    _part("EngineCase", Vector3(0.55, 0.28, 0.42), Vector3(0, 0.70, -0.06), black)
    for side in [-1.0, 1.0]:
        var x: float = float(side)
        _part("EngineCoolingFin_%d" % int(side), Vector3(0.08, 0.07, 0.40),
            Vector3(0.29 * x, 0.78, -0.05), steel)
        _part("FootPeg_%d" % int(side), Vector3(0.36, 0.08, 0.13),
            Vector3(0.42 * x, 0.65, 0.32), black)
        _part("RearShock_%d" % int(side), Vector3(0.075, 0.55, 0.085),
            Vector3(0.22 * x, 0.86, 0.68), steel)
        _part("TankAccent_%d" % int(side), Vector3(0.035, 0.13, 0.50),
            Vector3(0.30 * x, 1.12, -0.23), accent)
        _part("MirrorStem_%d" % int(side), Vector3(0.065, 0.48, 0.065),
            Vector3(0.47 * x, 1.75, -0.92), steel)
        _part("MirrorGlass_%d" % int(side), Vector3(0.28, 0.17, 0.09),
            Vector3(0.47 * x, 2.00, -0.92), black)
    _part("ExhaustPipe", Vector3(0.17, 0.15, 1.25),
        Vector3(0.35, 0.54, 0.44), steel)
    _part("ExhaustTip", Vector3(0.20, 0.21, 0.20),
        Vector3(0.35, 0.54, 1.12), black)
    _part("FrontMudguard", Vector3(0.35, 0.13, 0.80),
        Vector3(0.0, 0.88, -0.95), dark_red)
    _part("RearMudguard", Vector3(0.38, 0.12, 0.85),
        Vector3(0.0, 0.91, 0.87), dark_red)
    _part("TankKneeGuard", Vector3(0.62, 0.19, 0.35),
        Vector3(0, 0.97, -0.30), black)
    _part("RearGrabRail", Vector3(0.57, 0.08, 0.20),
        Vector3(0, 1.24, 0.85), steel)
    _part("FrontNumberPlate", Vector3(0.34, 0.22, 0.08),
        Vector3(0, 1.36, -1.08), Color(0.96, 0.92, 0.78))
    _part("SidePanelLeft", Vector3(0.06, 0.25, 0.49),
        Vector3(-0.31, 0.93, 0.36), dark_red)
    _part("SidePanelRight", Vector3(0.06, 0.25, 0.49),
        Vector3(0.31, 0.93, 0.36), dark_red)

## The complete visual bike can lean and bob WITHOUT tilting its
## static interaction collider or the player CharacterBody. The fork
## rotates as one unit, including headlamp, bars and the rolling wheel.
func _assemble_steering_fork() -> void:
    _front_assembly = Node3D.new()
    _front_assembly.name = "SteeringFork"
    _front_assembly.position = Vector3(0, 0.90, -0.95)
    _visual_rig.add_child(_front_assembly)
    var front_names: Array[String] = [
        "FrontWheel", "Fork", "Handlebar", "Headlight",
        "FrontMudguard", "FrontNumberPlate",
        "MirrorStem_-1", "MirrorStem_1",
        "MirrorGlass_-1", "MirrorGlass_1"
    ]
    for part_name in front_names:
        var part := _visual_rig.get_node_or_null(part_name) as Node3D
        if part != null:
            part.reparent(_front_assembly, true)

func update_ride_visuals(steer: float, signed_speed: float,
        delta: float, accepted_distance: float) -> void:
    if not is_instance_valid(_visual_rig) or delta <= 0.0:
        return
    var speed_ratio: float = clampf(absf(signed_speed) / 9.0, 0.0, 1.0)
    # A/D steer the visual fork toward the same side as the road heading.
    var steering_angle: float = -clampf(steer, -1.0, 1.0) * MAX_FRONT_STEER_RAD
    if is_instance_valid(_front_assembly):
        _front_assembly.rotation.y = lerpf(_front_assembly.rotation.y,
            steering_angle, minf(1.0, delta * 9.0))
    # Right bank is negative Z roll on an upright Godot model.
    # Reverse banking follows the reversed turning direction.
    var bank: float = -clampf(steer, -1.0, 1.0) * (
        signf(signed_speed) if absf(signed_speed) > 0.2 else 0.0
    ) * MAX_VISUAL_LEAN_RAD * speed_ratio
    _visual_rig.rotation.z = lerpf(_visual_rig.rotation.z,
        bank, minf(1.0, delta * 5.5))
    # Tiny arcade suspension bob driven ONLY by accepted road travel.
    # Stops bobbing when motion is blocked; this is not ground suspension.
    var bounce: float = 0.0
    if absf(accepted_distance) > 0.00001:
        bounce = sin(_wheel_roll_total * 0.45) * 0.025 * speed_ratio
    _visual_rig.position.y = lerpf(_visual_rig.position.y,
        bounce, minf(1.0, delta * 7.0))

func get_visual_lean() -> float:
    return _visual_rig.rotation.z if is_instance_valid(_visual_rig) else 0.0

func reset_ride_visuals() -> void:
    if is_instance_valid(_visual_rig):
        _visual_rig.rotation = Vector3.ZERO
        _visual_rig.position = Vector3.ZERO
    if is_instance_valid(_front_assembly):
        _front_assembly.rotation = Vector3.ZERO

func set_braking(active: bool) -> void:
    if not is_instance_valid(_brake_lamp):
        return
    var paint := _brake_lamp.material_override as StandardMaterial3D
    if paint != null:
        paint.albedo_color = Color(1.0, 0.25, 0.16) if active else Color(0.62, 0.06, 0.04)
        paint.emission_enabled = active
        paint.emission = Color(0.8, 0.10, 0.04)
        paint.emission_energy_multiplier = 1.5 if active else 0.0

func interact(actor: Node) -> void:
    if rider != null or not (actor is Node3D) or not actor.has_method("mount_bike"):
        return
    var player := actor as Node3D
    if player.global_position.distance_to(global_position) > MOUNT_DISTANCE_M:
        if player.has_signal("interaction_message"):
            player.emit_signal("interaction_message", "Move closer to the bike.")
        return
    player.call("mount_bike", self)

## Checks the complete vehicle envelope at a prospective world pose.
## The level is built from wide floor boxes on collision layer 1; those
## support the bike rather than obstruct it. Everything else is a hard
## blocker, including real vehicle bodies (4) and pedestrians (8).
func footprint_clear_at(world_origin: Vector3, yaw: float,
        excluding: Array[RID] = []) -> bool:
    if not is_inside_tree() or not world_origin.is_finite() or not is_finite(yaw):
        return false
    var query := _make_footprint_query(world_origin, yaw, Vector3.ZERO, excluding)
    return not _footprint_hits_blocker(query)

func _make_footprint_query(world_origin: Vector3, yaw: float,
        motion: Vector3, excluding: Array[RID]) -> PhysicsShapeQueryParameters3D:
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _footprint_shape
    var basis := Basis(Vector3.UP, yaw)
    query.transform = Transform3D(basis, world_origin + basis * FOOTPRINT_CENTER)
    query.motion = motion
    query.collision_mask = 1 | 2 | 4 | 8 | 16
    query.margin = FOOTPRINT_MARGIN
    var omit: Array[RID] = excluding.duplicate()
    # Own parked interaction shape must not block a legitimate mount;
    # other parked bikes/civic street posts remain real clearance hazards.
    omit.append(get_rid())
    if is_instance_valid(_rider_sensing_body):
        omit.append(_rider_sensing_body.get_rid())
    query.exclude = omit
    return query

func _footprint_hits_blocker(query: PhysicsShapeQueryParameters3D) -> bool:
    for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
        var body := hit.get("collider") as CollisionObject3D
        if body == null:
            continue
        if (body.collision_layer & 1) == 0:
            return true
        # Ignore a wide flat road/ground support plane, but never a wall.
        var support := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if support == null or not (support.shape is BoxShape3D):
            return true
        var support_box := support.shape as BoxShape3D
        var top: float = support.global_position.y + support_box.size.y * 0.5
        var bike_bottom: float = query.transform.origin.y - FOOTPRINT_SIZE.y * 0.5
        if top > bike_bottom + 0.035:
            return true
    return false

## NPC cars already sense layer 2 as vulnerable human road users. This
## query-only larger layer-2 body makes them see the entire mounted bike
## (including its front wheel) instead of only a narrow player capsule.
## It has mask 0: it never pushes or perturbs other physics bodies.
func enable_rider_sensing() -> void:
    if not is_instance_valid(_rider_sensing_body):
        _rider_sensing_body = StaticBody3D.new()
        _rider_sensing_body.name = "MountedBikeTrafficSensor"
        _rider_sensing_body.collision_layer = 2
        _rider_sensing_body.collision_mask = 0
        add_child(_rider_sensing_body)
        _rider_sensing_collision = CollisionShape3D.new()
        _rider_sensing_collision.name = "CollisionShape3D"
        _rider_sensing_collision.shape = _footprint_shape
        _rider_sensing_collision.position = FOOTPRINT_CENTER
        _rider_sensing_body.add_child(_rider_sensing_collision)
    _rider_sensing_body.collision_layer = 2

func disable_rider_sensing() -> void:
    if is_instance_valid(_rider_sensing_body):
        _rider_sensing_body.collision_layer = 0

func mount_to(player: Node3D) -> bool:
    if rider != null or player == null or not is_inside_tree():
        return false
    home_parent = get_parent()
    rider = player
    reparent(player)
    position = Vector3.ZERO
    rotation = Vector3.ZERO
    _wheel_roll_total = 0.0
    reset_ride_visuals()
    collision_layer = 0
    enable_rider_sensing()
    if is_instance_valid(_ride_label):
        _ride_label.visible = false
    return true

func park() -> bool:
    if rider == null or not is_instance_valid(home_parent):
        return false
    # Keep real location, not an invented spawn or road junction.
    reset_ride_visuals()
    reparent(home_parent)
    disable_rider_sensing()
    collision_layer = 16
    set_braking(false)
    rider = null
    if is_instance_valid(_ride_label):
        _ride_label.visible = true
    return true

func animate_wheels(distance_m: float) -> void:
    if not is_finite(distance_m) or absf(distance_m) <= 0.000001:
        return
    var angular_distance: float = distance_m / 0.43
    _wheel_roll_total += angular_distance
    # Cylinders were tilted by PI/2 around Z in _wheel(), so their
    # spin axle is the cylinder's LOCAL Y axis (world/bike X).
    # rotate_y() applies a parent-space yaw and makes them swivel flat.
    # rotate_object_local() spins around the actual wheel axle instead.
    if is_instance_valid(_wheel_front):
        _wheel_front.rotate_object_local(Vector3.UP, angular_distance)
    if is_instance_valid(_wheel_rear):
        _wheel_rear.rotate_object_local(Vector3.UP, angular_distance)
