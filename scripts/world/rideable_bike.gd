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
var _mounted_rider_visual: CivicMotorcycleRiderRig
const MAX_VISUAL_LEAN_RAD: float = 0.19
const MAX_FRONT_STEER_RAD: float = 0.38
var _headlamp: MeshInstance3D
var _brake_lamp: MeshInstance3D
var _wheel_roll_total: float = 0.0
## Bounded cosmetic contact compression. Never changes collision/body pose.
var _impact_compression: float = 0.0

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


## VEHICLE-RIDE-05C: round structural members; visual-only (no physics).
func _tube(part_name: String, start: Vector3, finish: Vector3,
        radius: float, color: Color) -> MeshInstance3D:
    var member := MeshInstance3D.new()
    member.name = part_name
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = start.distance_to(finish)
    cylinder.radial_segments = 10
    member.mesh = cylinder
    member.position = (start + finish) * 0.5
    member.basis = Basis(Quaternion(Vector3.UP, (finish - start).normalized()))
    var paint := StandardMaterial3D.new()
    paint.albedo_color = color
    paint.metallic = 0.5
    paint.roughness = 0.43
    member.material_override = paint
    _visual_rig.add_child(member)
    return member

func _design_05c_geometry() -> void:
    var steel := Color(0.57, 0.62, 0.69)
    var frame_color := Color(0.11, 0.15, 0.19)
    var rubber := Color(0.08, 0.09, 0.10)
    var paint := Color(0.77, 0.14, 0.10)
    # Hide the old blocky placeholders, preserving node identity for
    # legacy tests; structural parts below supply the visible silhouette.
    for part_name in ["Fork", "Handlebar", "Chassis", "EngineBlock",
            "ExhaustPipe", "ExhaustTip"]:
        var old := _visual_rig.get_node_or_null(part_name) as MeshInstance3D
        if old != null:
            old.visible = false
    for side in [-1.0, 1.0]:
        var sign_side: int = int(side)
        var x: float = side * 0.23
        _tube("FrameSpine_%d" % sign_side, Vector3(x, 0.75, 0.73),
            Vector3(x, 1.15, -0.38), 0.052, frame_color)
        _tube("FrameCradle_%d" % sign_side, Vector3(x, 0.75, 0.73),
            Vector3(x, 0.64, -0.27), 0.044, steel)
        _tube("RearSwingarm_%d" % sign_side, Vector3(x, 0.65, 0.30),
            Vector3(x, 0.43, 0.85), 0.063, frame_color)
        _tube("FrontForkStanchion_%d" % sign_side,
            Vector3(side * 0.18, 1.43, -0.83),
            Vector3(side * 0.18, 0.43, -0.95), 0.055, steel)
        _tube("FrontForkLower_%d" % sign_side,
            Vector3(side * 0.18, 0.78, -0.91),
            Vector3(side * 0.18, 0.43, -0.95), 0.078, frame_color)
        _tube("HandlebarRise_%d" % sign_side,
            Vector3(side * 0.18, 1.42, -0.90),
            Vector3(side * 0.30, 1.53, -0.92), 0.038, steel)
        _tube("HandlebarGrip_%d" % sign_side,
            Vector3(side * 0.30, 1.53, -0.92),
            Vector3(side * 0.50, 1.53, -0.92), 0.055, rubber)
        _tube("BrakeLever_%d" % sign_side,
            Vector3(side * 0.37, 1.51, -1.00),
            Vector3(side * 0.55, 1.49, -1.04), 0.014, steel)
        _tube("ExhaustHeader_%d" % sign_side,
            Vector3(side * 0.29, 0.69, -0.20),
            Vector3(side * 0.37, 0.52, 0.55), 0.055, steel)
        _tube("ExhaustCan_%d" % sign_side,
            Vector3(side * 0.37, 0.53, 0.53),
            Vector3(side * 0.37, 0.54, 1.12), 0.105, frame_color)
    _tube("HandlebarCrossbar", Vector3(-0.30, 1.53, -0.92),
        Vector3(0.30, 1.53, -0.92), 0.04, steel)
    _tube("TripleClamp", Vector3(-0.23, 1.39, -0.87),
        Vector3(0.23, 1.39, -0.87), 0.07, steel)
    _tube("EngineCylinder", Vector3(0, 0.61, -0.10),
        Vector3(0, 1.04, -0.10), 0.23, steel)
    for fin in range(5):
        _tube("EngineFin_%d" % fin,
            Vector3(-0.29, 0.72 + float(fin) * 0.065, -0.10),
            Vector3(0.29, 0.72 + float(fin) * 0.065, -0.10),
            0.026, frame_color)
    _tube("TankCenterRidge", Vector3(0, 1.32, -0.50),
        Vector3(0, 1.32, 0.05), 0.038, paint)
    _tube("RearSubframe", Vector3(-0.23, 1.10, 0.92),
        Vector3(0.23, 1.10, 0.92), 0.05, steel)

## VEHICLE-RIDE-05C-FRONT: symmetric street-bike front end.
## Every detail is visual only and follows the existing SteeringFork.
func _front_round_part(part_name: String, radius: float, depth: float,
        at: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = depth
    cylinder.radial_segments = 16
    part.mesh = cylinder
    part.position = at
    # Cylinder symmetry axis is Y; motorcycle faces -Z.
    part.rotation.x = PI * 0.5
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.35
    material.roughness = 0.34
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = emission
    part.material_override = material
    _visual_rig.add_child(part)
    return part

func _front_orb(part_name: String, at: Vector3, dimensions: Vector3,
        color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    var sphere := SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    sphere.radial_segments = 12
    sphere.rings = 8
    part.mesh = sphere
    part.position = at
    part.scale = dimensions
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.25
    mat.roughness = 0.42
    part.material_override = mat
    _visual_rig.add_child(part)
    return part

func _design_front_assembly() -> void:
    var dark := Color(0.08, 0.11, 0.14)
    var steel := Color(0.65, 0.70, 0.74)
    var body_red := Color(0.77, 0.14, 0.10)
    var amber := Color(1.0, 0.55, 0.10)
    # Legacy square lamp and floating rectangular number plate retained
    # by name for compatibility, but replaced by round functional geometry.
    for legacy_name in ["Headlight", "FrontNumberPlate", "FrontMudguard"]:
        var old := _visual_rig.get_node_or_null(legacy_name) as MeshInstance3D
        if old != null:
            old.visible = false
    _front_round_part("HeadlampBucket", 0.245, 0.20,
        Vector3(0.0, 1.22, -1.11), dark)
    _front_round_part("HeadlampBezel", 0.225, 0.042,
        Vector3(0.0, 1.22, -1.235), steel)
    _front_round_part("HeadlampLens", 0.194, 0.028,
        Vector3(0.0, 1.22, -1.266), Color(1.0, 0.95, 0.74), 0.45)
    _front_orb("FrontCowl", Vector3(0.0, 1.43, -1.07),
        Vector3(0.51, 0.23, 0.27), body_red)
    _front_round_part("Speedometer", 0.13, 0.07,
        Vector3(0.0, 1.59, -0.78), dark)
    # Twin turn signals, not rigid rectangles floating in front of tire.
    for side in [-1.0, 1.0]:
        var n: int = int(side)
        _tube("IndicatorStalk_%d" % n,
            Vector3(side * 0.22, 1.22, -1.05),
            Vector3(side * 0.43, 1.22, -1.13), 0.028, dark)
        _front_orb("FrontIndicator_%d" % n,
            Vector3(side * 0.45, 1.22, -1.15),
            Vector3(0.16, 0.13, 0.12), amber)
        _tube("ForkDustSeal_%d" % n,
            Vector3(side * 0.18, 0.85, -0.905),
            Vector3(side * 0.18, 0.78, -0.913), 0.09, dark)
        _tube("AxleEnd_%d" % n,
            Vector3(side * 0.13, 0.43, -0.95),
            Vector3(side * 0.235, 0.43, -0.95), 0.065, steel)
        # A rounded fender follows the upper circumference of the tire
        # and stays inside the previously validated bike footprint.
        var last_point := Vector3.ZERO
        for index in range(9):
            var angle: float = -0.98 + float(index) * 1.96 / 8.0
            var point := Vector3(side * 0.17,
                0.43 + 0.485 * cos(angle),
                -0.95 + 0.485 * sin(angle))
            if index > 0:
                _tube("FrontFenderRib_%d_%d" % [n, index],
                    last_point, point, 0.048, body_red)
            last_point = point
    _tube("FrontFenderBridge", Vector3(-0.17, 0.915, -0.95),
        Vector3(0.17, 0.915, -0.95), 0.065, body_red)
    _tube("FrontBrakeHose", Vector3(-0.27, 1.48, -0.93),
        Vector3(-0.24, 0.64, -0.96), 0.017, dark)

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
    _design_05c_geometry()
    _design_front_assembly()
    _design_08_rear_identity()
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

## VEH-ART-08: fuller motorcycle rear silhouette, without new colliders
## or changing the steering fork / mounted-rider hand targets.
func _design_08_rear_identity() -> void:
    var charcoal := Color(0.12, 0.15, 0.19)
    var silver := Color(0.64, 0.69, 0.72)
    var red := Color(0.75, 0.15, 0.12)
    var cream := Color(0.93, 0.90, 0.76)
    _part("RearTailCowl08", Vector3(0.48, 0.17, 0.38),
        Vector3(0.0, 1.125, 0.83), red)
    _part("RearPlate08", Vector3(0.36, 0.19, 0.035),
        Vector3(0.0, 0.78, 1.29), cream)
    _part("RearPlateSupport08", Vector3(0.08, 0.34, 0.10),
        Vector3(0.0, 0.91, 1.22), charcoal)
    _part("ChainGuard08", Vector3(0.055, 0.105, 0.68),
        Vector3(-0.22, 0.53, 0.58), charcoal)
    _part("RearReflector08", Vector3(0.33, 0.08, 0.035),
        Vector3(0.0, 0.62, 1.325), red)
    for side in [-1.0, 1.0]:
        var marker: String = "L" if side < 0.0 else "R"
        _part("SideTankInset08_" + marker, Vector3(0.035, 0.10, 0.38),
            Vector3(side * 0.316, 1.17, -0.31), silver)
        _part("PassengerPeg08_" + marker, Vector3(0.21, 0.045, 0.11),
            Vector3(side * 0.35, 0.71, 0.73), charcoal)

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
        "MirrorGlass_-1", "MirrorGlass_1",
        "HandlebarCrossbar", "TripleClamp",
        "FrontForkStanchion_-1", "FrontForkStanchion_1",
        "FrontForkLower_-1", "FrontForkLower_1",
        "HandlebarRise_-1", "HandlebarRise_1",
        "HandlebarGrip_-1", "HandlebarGrip_1",
        "BrakeLever_-1", "BrakeLever_1",
        "HeadlampBucket", "HeadlampBezel", "HeadlampLens",
        "FrontCowl", "Speedometer", "FrontFenderBridge",
        "FrontBrakeHose", "IndicatorStalk_-1", "IndicatorStalk_1",
        "FrontIndicator_-1", "FrontIndicator_1",
        "ForkDustSeal_-1", "ForkDustSeal_1",
        "AxleEnd_-1", "AxleEnd_1"
    ]
    for side in [-1, 1]:
        for index in range(1, 9):
            front_names.append("FrontFenderRib_%d_%d" % [side, index])
    for part_name in front_names:
        var part := _visual_rig.get_node_or_null(part_name) as Node3D
        if part != null:
            part.reparent(_front_assembly, true)

## Contacts stop the physical bike first; this visual response is a short,
## bounded fork/body dip with no impulse into cars or rider displacement.
func register_impact(speed_mps: float) -> void:
    if is_finite(speed_mps) and speed_mps > 0.15:
        _impact_compression = maxf(_impact_compression,
            clampf(speed_mps / 14.0, 0.0, 1.0))

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
    # VEHICLE-RIDE-05D: visual brake-dive and rebound, always below a
    # mild arcade limit. Do not change root physics or tire collision.
    var braking: bool = absf(signed_speed) > 0.3 and (
        absf(accepted_distance) < absf(signed_speed) * delta * 0.45)
    var target_pitch: float = (-0.045 if braking else 0.0) - (
        _impact_compression * 0.065)
    _visual_rig.rotation.x = lerpf(_visual_rig.rotation.x,
        target_pitch, minf(1.0, delta * 10.0 if _impact_compression > 0.0 else delta * 4.5))
    _impact_compression = move_toward(_impact_compression, 0.0, delta * 3.0)
    # Tiny arcade suspension bob driven ONLY by accepted road travel.
    # Stops bobbing when motion is blocked; this is not ground suspension.
    var bounce: float = 0.0
    if absf(accepted_distance) > 0.00001:
        bounce = sin(_wheel_roll_total * 0.45) * 0.025 * speed_ratio
    _visual_rig.position.y = lerpf(_visual_rig.position.y,
        bounce, minf(1.0, delta * 7.0))
    # Evaluate hands after steering, banking, pitch and rebound settle.
    # Both grips and hand meshes share the resulting visual transform.
    if is_instance_valid(_mounted_rider_visual):
        _mounted_rider_visual.update_targets()

func get_visual_lean() -> float:
    return _visual_rig.rotation.z if is_instance_valid(_visual_rig) else 0.0

func reset_ride_visuals() -> void:
    _impact_compression = 0.0
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

## Never identify physical ground by a fragile node name. Godot may
## auto-name a CollisionShape3D in a script-built road. Only a body with
## exactly one directly attached, enabled shape is eligible for the flat
## support exemption. Compound obstacles remain blocking.
static func single_collision_shape(body: CollisionObject3D) -> CollisionShape3D:
    if body == null:
        return null
    var found: CollisionShape3D = null
    for child in body.get_children():
        if child is CollisionShape3D:
            var candidate := child as CollisionShape3D
            if candidate.disabled:
                continue
            if found != null:
                return null
            found = candidate
    return found

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
    # The road beneath the tires is support, not a horizontal obstacle.
    # Exclude ONLY a verified broad horizontal support from the swept
    # physics query; otherwise cast_motion may report zero travel while
    # reversing with a small settled-ground penetration. Walls, cars,
    # pedestrians and raised structures remain collision blockers.
    if motion.length_squared() > 0.0000001:
        var road_ray := PhysicsRayQueryParameters3D.create(
            world_origin + Vector3.UP * 1.0,
            world_origin + Vector3.DOWN * 1.8)
        road_ray.collision_mask = 1
        road_ray.exclude = omit
        var road_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(road_ray)
        if not road_hit.is_empty() and (road_hit["normal"] as Vector3).y > 0.98:
            var road_body := road_hit.get("collider") as CollisionObject3D
            if road_body != null:
                var support := single_collision_shape(road_body)
                if support != null and support.shape is BoxShape3D:
                    var slab := support.shape as BoxShape3D
                    var top: float = support.global_position.y + slab.size.y * 0.5
                    if slab.size.x >= 2.0 and slab.size.z >= 2.0 and slab.size.y <= 1.0 and (
                            top <= world_origin.y + 0.20):
                        omit.append(road_body.get_rid())
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
        var support := single_collision_shape(body)
        if support == null or not (support.shape is BoxShape3D):
            return true
        var support_box := support.shape as BoxShape3D
        var top: float = support.global_position.y + support_box.size.y * 0.5
        var bike_root_y: float = query.transform.origin.y - FOOTPRINT_CENTER.y
        var support_is_road: bool = support_box.size.x >= 2.0 and (
            support_box.size.z >= 2.0) and support_box.size.y <= 1.0 and (
            support.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.98)
        # Long riding can settle the root a few centimetres into a wide
        # road slab. It is still road support, not a vehicle/wall overlap.
        # Cap tolerance; tall or rotated world geometry remains blocking.
        if not support_is_road or top > bike_root_y + 0.20:
            return true
    return false

## Escape an already-overlapping front wheel without ghosting through
## buildings, traffic or pedestrians. PhysicsServer contact pairs expose
## penetration depths for the full 05A footprint. Reversing is accepted
## only if it REDUCES penetration and does not touch a new obstruction.
## This is intentionally a short physics-step recovery, not teleportation.
func reverse_escapes_overlap(world_origin: Vector3, yaw: float,
        backward_motion: Vector3, excluding: Array[RID] = []) -> bool:
    if backward_motion.length_squared() < 0.0000001:
        return false
    var current_query := _make_footprint_query(
        world_origin, yaw, Vector3.ZERO, excluding)
    if not _footprint_hits_blocker(current_query):
        return false
    var next_query := _make_footprint_query(
        world_origin + backward_motion, yaw, Vector3.ZERO, excluding)
    _exclude_support_from_recovery(current_query, world_origin)
    _exclude_support_from_recovery(next_query, world_origin + backward_motion)
    var current_hits := _blocking_colliders(current_query)
    var next_hits := _blocking_colliders(next_query)
    if current_hits.is_empty():
        return false
    for next_body in next_hits:
        if not current_hits.has(next_body):
            return false
    # A near-touching margin may report an overlap with zero measured
    # penetration. A completely clear next step is always a safe retreat.
    if next_hits.is_empty():
        return true
    var before_depth: float = _footprint_contact_depth(current_query)
    var after_depth: float = _footprint_contact_depth(next_query)
    return before_depth > 0.00001 and after_depth < before_depth - 0.00001

func _exclude_support_from_recovery(query: PhysicsShapeQueryParameters3D,
        origin: Vector3) -> void:
    var ray := PhysicsRayQueryParameters3D.create(
        origin + Vector3.UP * 1.0, origin + Vector3.DOWN * 1.8)
    ray.collision_mask = 1
    ray.exclude = query.exclude
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty() or (hit["normal"] as Vector3).y < 0.98:
        return
    var body := hit.get("collider") as CollisionObject3D
    var support := single_collision_shape(body)
    if support == null or not (support.shape is BoxShape3D):
        return
    var box := support.shape as BoxShape3D
    var top: float = support.global_position.y + box.size.y * 0.5
    if box.size.x >= 2.0 and box.size.z >= 2.0 and box.size.y <= 1.0 and (
            top <= origin.y + 0.20):
        var omitted: Array[RID] = query.exclude.duplicate()
        omitted.append(body.get_rid())
        query.exclude = omitted

func _blocking_colliders(query: PhysicsShapeQueryParameters3D) -> Array[CollisionObject3D]:
    var result: Array[CollisionObject3D] = []
    for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
        var body := hit.get("collider") as CollisionObject3D
        if body == null:
            continue
        # Road support never counts as a lateral crash blocker.
        if (body.collision_layer & 1) != 0:
            var support := single_collision_shape(body)
            if support != null and support.shape is BoxShape3D:
                var slab := support.shape as BoxShape3D
                var top: float = support.global_position.y + slab.size.y * 0.5
                var root_y: float = query.transform.origin.y - FOOTPRINT_CENTER.y
                if slab.size.x >= 2.0 and slab.size.z >= 2.0 and slab.size.y <= 1.0 and (
                        support.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.98) and (
                        top <= root_y + 0.20):
                    continue
        if not result.has(body):
            result.append(body)
    return result

func _footprint_contact_depth(query: PhysicsShapeQueryParameters3D) -> float:
    var contacts: PackedVector3Array = get_world_3d().direct_space_state.collide_shape(query, 64)
    var deepest: float = 0.0
    for i in range(0, contacts.size() - 1, 2):
        deepest = maxf(deepest, contacts[i].distance_to(contacts[i + 1]))
    return deepest

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
    _mounted_rider_visual = CivicMotorcycleRiderRig.new()
    _mounted_rider_visual.name = "MountedRiderRig"
    _visual_rig.add_child(_mounted_rider_visual)
    var appearance: Node3D = player.get_node_or_null("Visual") as Node3D
    _mounted_rider_visual.configure(_front_assembly, appearance)
    if is_instance_valid(_ride_label):
        _ride_label.visible = false
    return true

func park() -> bool:
    if rider == null or not is_instance_valid(home_parent):
        return false
    # Keep real location, not an invented spawn or road junction.
    reset_ride_visuals()
    if is_instance_valid(_mounted_rider_visual):
        _mounted_rider_visual.detach_targets()
        _mounted_rider_visual.queue_free()
        _mounted_rider_visual = null
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
