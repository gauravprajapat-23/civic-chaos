class_name CivicVehicleVisuals
extends Node3D
## ART-CAR-01: light-weight, low-poly sedan presentation layered on the
## unchanged CivicVehicleAgent collision/route. No physics, RNG or gameplay.
## -Z is the car front, matching the road-following transform.
const PALETTE: Array[Color] = [
    Color(0.13, 0.29, 0.48), # Deep slate blue
    Color(0.49, 0.12, 0.11), # Oxblood red
    Color(0.68, 0.71, 0.71), # Metallic silver
    Color(0.18, 0.21, 0.23), # Graphite
    Color(0.18, 0.33, 0.28)  # Forest green
]
## CAR-ART-05D: bounded, deterministic visual variety. Each car's
## original first-route lane ID already survives checkpoint restoration.
## Do not use RNG, object IDs, simulation ticks or new save fields.
const DRIVER_SHIRTS: Array[Color] = [
    Color(0.25, 0.43, 0.54), Color(0.61, 0.29, 0.23),
    Color(0.25, 0.44, 0.32), Color(0.51, 0.43, 0.61),
    Color(0.64, 0.57, 0.30)
]
const DRIVER_SKIN: Array[Color] = [
    Color(0.58, 0.34, 0.22), Color(0.37, 0.21, 0.14),
    Color(0.70, 0.46, 0.30), Color(0.49, 0.29, 0.19),
    Color(0.63, 0.41, 0.27)
]
const DRIVER_HAIR: Array[Color] = [
    Color(0.095, 0.075, 0.067), Color(0.18, 0.12, 0.08),
    Color(0.055, 0.055, 0.06), Color(0.29, 0.18, 0.11),
    Color(0.115, 0.09, 0.085)
]
const SEAT_TRIMS: Array[Color] = [
    Color(0.20, 0.23, 0.24), Color(0.27, 0.22, 0.19),
    Color(0.18, 0.22, 0.27), Color(0.23, 0.23, 0.20),
    Color(0.24, 0.19, 0.21)
]
const RIM_FINISHES: Array[Color] = [
    Color(0.46, 0.50, 0.54), Color(0.64, 0.65, 0.63),
    Color(0.31, 0.35, 0.39), Color(0.56, 0.50, 0.44),
    Color(0.40, 0.44, 0.48)
]
var _paint: StandardMaterial3D
var _glass: StandardMaterial3D
var _mirror_glass: StandardMaterial3D
var _trim: StandardMaterial3D
var _metal: StandardMaterial3D
var _rubber: StandardMaterial3D
var _hub_finish: StandardMaterial3D
var _headlamp: StandardMaterial3D
var _tail: StandardMaterial3D
var _upholstery: StandardMaterial3D
var _uniform: StandardMaterial3D
var _skin: StandardMaterial3D
var _hair: StandardMaterial3D
var _color_slot: int = 0
var _driver_slot: int = 0
var _braking: bool = false
## CAR-ART-05E: only presentation nodes are hidden at distance. Vehicle
## physics, visible body/roof, routing and checkpoint remain unchanged.
const DETAIL_NEAR: int = 0
const DETAIL_MID: int = 1
const DETAIL_FAR: int = 2
const NEAR_DISTANCE_M: float = 24.0
const FAR_DISTANCE_M: float = 54.0
const LOD_HYSTERESIS_M: float = 4.0
var _detail_level: int = DETAIL_NEAR
var _wheel_rotation: float = 0.0
var _steer_visual: float = 0.0

func _ready() -> void:
    # Opaque PBR materials remain readable in Godot Mobile/Compatibility.
    # Metallic values do not imply actual planar/screen-space reflections.
    _paint = _material(PALETTE[0], 0.31, 0.25)
    _paint.clearcoat_enabled = true
    _paint.clearcoat = 0.55
    _paint.clearcoat_roughness = 0.22
    _glass = _material(Color(0.11, 0.19, 0.25), 0.19, 0.09)
    _mirror_glass = _material(Color(0.49, 0.61, 0.66), 0.14, 0.55)
    _trim = _material(Color(0.065, 0.075, 0.085), 0.76)
    _metal = _material(Color(0.48, 0.53, 0.58), 0.36, 0.52)
    _rubber = _material(Color(0.075, 0.079, 0.082), 0.94)
    _hub_finish = _material(Color(0.46, 0.50, 0.54), 0.41, 0.62)
    _headlamp = _material(Color(0.88, 0.90, 0.81), 0.30)
    _tail = _material(Color(0.66, 0.09, 0.07), 0.34)
    _upholstery = _material(Color(0.20, 0.23, 0.24), 0.91)
    _uniform = _material(Color(0.25, 0.43, 0.54), 0.91)
    _skin = _material(Color(0.58, 0.34, 0.22), 0.93)
    _hair = _material(Color(0.095, 0.075, 0.067), 0.94)
    # Keep tinted automotive glass readable, but allow the actual driver to
    # be seen. Per-mesh transparency is presentation-only, never collision.
    _glass.albedo_color = Color(0.10, 0.17, 0.23, 0.32)
    _glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    # Avoid drawing both faces of every window; cabin structural paint stays opaque.
    _glass.cull_mode = BaseMaterial3D.CULL_BACK
    _headlamp.emission_enabled = true
    _headlamp.emission = Color(0.36, 0.34, 0.22)
    _tail.emission_enabled = true
    _tail.emission = Color(0.24, 0.015, 0.015)
    _reshape_legacy()
    _build_details()
    _build_driver_and_interior()
    _batch_wheel_spokes()
    set_detail_level(DETAIL_NEAR)

static func _material(color: Color, rough: float, metallic: float = 0.0) -> StandardMaterial3D:
    var value := StandardMaterial3D.new()
    value.albedo_color = color
    value.roughness = rough
    value.metallic = metallic
    return value

func _reshape_legacy() -> void:
    var base: MeshInstance3D = get_parent().get_node_or_null("Visual") as MeshInstance3D
    var cabin: MeshInstance3D = get_parent().get_node_or_null("Cabin") as MeshInstance3D
    if base != null:
        var chassis := BoxMesh.new()
        chassis.size = Vector3(1.60, 0.52, 2.94)
        base.mesh = chassis
        base.position = Vector3(0, 0.58, 0)
        base.material_override = _paint
    if cabin != null:
        # CAR-ART-05B: the original full-height six-sided shell obscured
        # the driver and double-rendered transparent polygons. Rebuild it
        # as an OPAQUE low beltline; windows and windshield are separate,
        # single-layer alpha panes with no hidden glass shell behind them.
        cabin.mesh = _tapered_cabin()
        cabin.position = Vector3(0, 1.035, 0.10)
        cabin.material_override = _paint

func _tapered_cabin() -> ArrayMesh:
    # Existing scene contract: one ArrayMesh surface. Only the lower
    # body-colored door belt remains; no opaque roof/window faces. Upper
    # windshield, sides, rear glazing and pillars are separate meshes.
    var corners: Array[Vector3] = [
        Vector3(-0.675, -0.225, -0.75), Vector3(0.675, -0.225, -0.75),
        Vector3(0.675, -0.225, 0.78), Vector3(-0.675, -0.225, 0.78),
        Vector3(-0.645, -0.095, -0.71), Vector3(0.645, -0.095, -0.71),
        Vector3(0.645, -0.095, 0.72), Vector3(-0.645, -0.095, 0.72)
    ]
    var faces: Array = [
        [0, 4, 5, 1], [1, 5, 6, 2],
        [2, 6, 7, 3], [3, 7, 4, 0],
        [4, 7, 6, 5]
    ]
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for face in faces:
        for offset in [0, 1, 2, 0, 2, 3]:
            surface.add_vertex(corners[int(face[offset])])
    surface.generate_normals()
    return surface.commit()

func set_lane_variant(lane_id: int) -> void:
    # Preserve the established lane-based body paint contract. Derive a
    # separate identity from that same original lane, without touching the
    # traffic RNG or updating the driver's look on subsequent route steps.
    _color_slot = posmod(lane_id, PALETTE.size())
    _driver_slot = posmod(lane_id * 7 + 3, DRIVER_SHIRTS.size())
    if _paint != null:
        _paint.albedo_color = PALETTE[_color_slot]
    if _uniform != null:
        _uniform.albedo_color = DRIVER_SHIRTS[_driver_slot]
    if _skin != null:
        _skin.albedo_color = DRIVER_SKIN[_driver_slot]
    if _hair != null:
        _hair.albedo_color = DRIVER_HAIR[_driver_slot]
    if _upholstery != null:
        _upholstery.albedo_color = SEAT_TRIMS[_driver_slot]
    if _hub_finish != null:
        _hub_finish.albedo_color = RIM_FINISHES[_driver_slot]
    # Five reversible hair silhouettes using the same low-poly mesh; no
    # additional drawing surfaces, collisions, or separate occupant scripts.
    var hair: MeshInstance3D = get_node_or_null("DriverHair") as MeshInstance3D
    if hair != null:
        hair.scale = Vector3(1.0 + float(_driver_slot % 3) * 0.08,
            1.0 + float(_driver_slot % 2) * 0.18, 1.0)
    # Vehicle badge uses existing metal material; no unique license plate
    # text/font needed for thousands of moving vehicles.

func color_variant() -> int:
    return _color_slot

func driver_variant() -> int:
    return _driver_slot

func visual_identity() -> Dictionary:
    return {"paint": _color_slot, "driver": _driver_slot}

## Stable hysteresis prevents visible popping when a moving camera
## hovers near one of the boundaries. LOD is deliberately not saved.
func update_lod_distance(distance_m: float) -> void:
    if not is_finite(distance_m) or distance_m < 0.0:
        return
    var level: int = _detail_level
    match _detail_level:
        DETAIL_NEAR:
            if distance_m > FAR_DISTANCE_M + LOD_HYSTERESIS_M:
                level = DETAIL_FAR
            elif distance_m > NEAR_DISTANCE_M + LOD_HYSTERESIS_M:
                level = DETAIL_MID
        DETAIL_MID:
            if distance_m < NEAR_DISTANCE_M - LOD_HYSTERESIS_M:
                level = DETAIL_NEAR
            elif distance_m > FAR_DISTANCE_M + LOD_HYSTERESIS_M:
                level = DETAIL_FAR
        DETAIL_FAR:
            if distance_m < NEAR_DISTANCE_M - LOD_HYSTERESIS_M:
                level = DETAIL_NEAR
            elif distance_m < FAR_DISTANCE_M - LOD_HYSTERESIS_M:
                level = DETAIL_MID
    set_detail_level(level)

func detail_level() -> int:
    return _detail_level

func set_detail_level(level: int) -> void:
    if level < DETAIL_NEAR or level > DETAIL_FAR:
        return
    _detail_level = level
    for part in get_children():
        if not (part is VisualInstance3D):
            continue
        var name: String = str(part.name)
        # The legacy spoke nodes are kept for older scene contracts, but
        # permanently hidden: a single MultiMesh renders all 20 instead.
        if name.contains("WheelSpoke_"):
            (part as VisualInstance3D).visible = false
            continue
        if name == "BatchedWheelSpokes":
            (part as VisualInstance3D).visible = level == DETAIL_NEAR
            continue
        if level == DETAIL_NEAR:
            (part as VisualInstance3D).visible = true
        elif level == DETAIL_MID:
            (part as VisualInstance3D).visible = not _tiny_decoration(name)
        else:
            (part as VisualInstance3D).visible = _distant_silhouette(name)

static func _tiny_decoration(name: String) -> bool:
    return name.begins_with("GrilleSlat_") or name.contains("WheelFace_") or name.begins_with("FrontHub_") or name.begins_with("RearHub_") or name.begins_with("DoorSeam_") or name.begins_with("DoorHandle_") or name.begins_with("FrontDoor") or name.begins_with("RearDoor") or name.begins_with("MirrorGlass_") or name.begins_with("MirrorMount_") or name.begins_with("FrontBadge") or name.begins_with("WindowSill_") or name.begins_with("HoodCenterCrease") or name.begins_with("Waistline_") or name.begins_with("GrilleSide_") or name.begins_with("GrilleSurround") or name.begins_with("FrontSideMarker") or name.begins_with("RearSideReflector")

static func _distant_silhouette(name: String) -> bool:
    return name == "Hood" or name == "Trunk" or name == "Roof" or name == "FrontGrille" or name == "FrontBumper" or name == "RearBumper" or name == "RearTrunkLip" or name == "RearTailPanel" or name.begins_with("FrontLamp_") or name.begins_with("RearLamp_")

## Combining 20 identical small spokes into a *single* MultiMesh draw
## group avoids 20 tiny draw submissions per near car. No collision/RNG.
func _batch_wheel_spokes() -> void:
    var spokes: Array[MeshInstance3D] = []
    for part in get_children():
        if part is MeshInstance3D and str(part.name).contains("WheelSpoke_"):
            spokes.append(part as MeshInstance3D)
    if spokes.is_empty():
        return
    var batch := MultiMeshInstance3D.new()
    batch.name = "BatchedWheelSpokes"
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.025, 0.048, 0.19)
    mesh.material = _hub_finish
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = spokes.size()
    for index in range(spokes.size()):
        multi.set_instance_transform(index, spokes[index].transform)
        spokes[index].visible = false
    batch.multimesh = multi
    batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(batch)

## CAR-ART-05F: purely cosmetic motion fed by *actual* route travel.
## Front wheels steer slightly in curves; tire tread and disc rotate on
## every moving axle. Nothing writes into car position/speed/traffic RNG.
func update_motion_visuals(actual_travel_m: float, yaw_delta_rad: float) -> void:
    if not is_finite(actual_travel_m) or not is_finite(yaw_delta_rad):
        return
    _wheel_rotation = wrapf(_wheel_rotation + maxf(0.0, actual_travel_m) / 0.34, -PI, PI)
    _steer_visual = clampf(yaw_delta_rad * 3.0, -0.38, 0.38)
    var owner: Node = get_parent()
    if owner == null:
        return
    for side in ["L", "R"]:
        for axle in ["Front", "Rear"]:
            var key: String = "Wheel_" + side + "_" + axle
            var wheel: MeshInstance3D = owner.get_node_or_null(key) as MeshInstance3D
            if wheel != null:
                wheel.rotation.x = _wheel_rotation
                if axle == "Front":
                    wheel.rotation.y = _steer_visual
            var hub: MeshInstance3D = get_node_or_null(axle + "Hub_" + side) as MeshInstance3D
            if hub != null:
                hub.rotation.x = _wheel_rotation
            var face: MeshInstance3D = get_node_or_null(axle + "WheelFace_" + side) as MeshInstance3D
            if face != null:
                face.rotation.x = _wheel_rotation
    var steering: MeshInstance3D = get_node_or_null("SteeringWheel") as MeshInstance3D
    if steering != null:
        steering.rotation.z = _steer_visual * 0.40
    if _detail_level == DETAIL_NEAR:
        _update_batched_spoke_rotation()

func _update_batched_spoke_rotation() -> void:
    var group: MultiMeshInstance3D = get_node_or_null("BatchedWheelSpokes") as MultiMeshInstance3D
    if group == null or group.multimesh == null:
        return
    var i: int = 0
    for spoke in get_children():
        if not (spoke is MeshInstance3D) or not str(spoke.name).contains("WheelSpoke_"):
            continue
        var wheel_side: float = -1.0 if str(spoke.name).contains("_L_") else 1.0
        var axle_z: float = -0.95 if str(spoke.name).begins_with("Front") else 0.95
        var center := Vector3(wheel_side * 0.935, 0.36, axle_z)
        var motion := Transform3D(Basis(Vector3.RIGHT, _wheel_rotation), Vector3.ZERO)
        var initial: Transform3D = (spoke as MeshInstance3D).transform
        var relative: Vector3 = initial.origin - center
        var rotated := Transform3D(motion.basis * initial.basis,
            center + motion.basis * relative)
        group.multimesh.set_instance_transform(i, rotated)
        i += 1

func set_braking(value: bool) -> void:
    if _braking == value or _tail == null:
        return
    _braking = value
    # Shared lamp material; no per-frame mesh or material allocations.
    _tail.emission = Color(0.88, 0.08, 0.035) if value else Color(0.24, 0.015, 0.015)


func _box(name: String, center: Vector3, dimensions: Vector3,
        surface: Material, tilt: float = 0.0) -> void:
    var item := MeshInstance3D.new()
    item.name = name
    var shape := BoxMesh.new()
    shape.size = dimensions
    item.mesh = shape
    item.position = center
    item.rotation.x = tilt
    item.material_override = surface
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(item)

## A visible, seated low-poly driver on the RIGHT (Indian road traffic).
## All children are MeshInstance3D with no physics, scripts or gameplay input.
## Keep the head inside the cabin roof and away from the windscreen plane.
func _build_driver_and_interior() -> void:
    _box("CabinFloor", Vector3(0, 0.825, 0.12),
        Vector3(1.29, 0.055, 1.55), _upholstery)
    for side in [-1, 1]:
        var x: float = float(side) * 0.34
        var label: String = "L" if side < 0 else "R"
        _box("FrontSeat_" + label, Vector3(x, 0.99, -0.12),
            Vector3(0.43, 0.34, 0.42), _upholstery)
        _box("SeatBack_" + label, Vector3(x, 1.17, 0.12),
            Vector3(0.42, 0.43, 0.11), _upholstery)
        _box("HeadRest_" + label, Vector3(x, 1.19, 0.13),
            Vector3(0.23, 0.10, 0.13), _upholstery)
    # Right-hand-drive steering column and simple circular wheel.
    _box("Dashboard", Vector3(0, 0.96, -0.61),
        Vector3(1.23, 0.13, 0.22), _trim)
    _box("SteeringHub", Vector3(0.35, 1.073, -0.46),
        Vector3(0.075, 0.075, 0.12), _metal)
    var wheel := MeshInstance3D.new()
    wheel.name = "SteeringWheel"
    var rim := TorusMesh.new()
    rim.inner_radius = 0.105
    rim.outer_radius = 0.136
    rim.rings = 6
    rim.ring_segments = 12
    wheel.mesh = rim
    wheel.rotation.x = 0.48
    wheel.position = Vector3(0.35, 1.10, -0.49)
    wheel.material_override = _trim
    wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(wheel)
    # The torso and head are true geometry behind glass, not a UI decal.
    _box("DriverTorso", Vector3(0.34, 0.995, -0.09),
        Vector3(0.35, 0.30, 0.22), _uniform)
    _box("DriverNeck", Vector3(0.34, 1.03, -0.10),
        Vector3(0.10, 0.08, 0.11), _skin)
    _sphere("DriverHead", Vector3(0.34, 1.115, -0.12),
        0.105, _skin)
    _box("DriverHair", Vector3(0.34, 1.215, -0.13),
        Vector3(0.205, 0.045, 0.205), _hair)
    for side in [-1, 1]:
        var x: float = 0.34 + float(side) * 0.14
        _box("DriverArm_%d" % side, Vector3(x, 1.005, -0.29),
            Vector3(0.095, 0.105, 0.34), _uniform)
    # A visible A/B-pillar gives window structure without an opaque cabin.
    for side in [-1, 1]:
        var x: float = float(side) * 0.64
        _box("WindshieldPillar_%d" % side, Vector3(x, 1.095, -0.61),
            Vector3(0.035, 0.31, 0.047), _paint, -0.44)
        _box("RearPillar_%d" % side, Vector3(x, 1.095, 0.69),
            Vector3(0.035, 0.31, 0.047), _paint, 0.40)

func _sphere(name: String, location: Vector3, radius: float, surface: Material) -> void:
    var part := MeshInstance3D.new()
    part.name = name
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    shape.radial_segments = 10
    shape.rings = 5
    part.mesh = shape
    part.position = location
    part.material_override = surface
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(part)

func _hub(name: String, location: Vector3) -> void:
    var item := MeshInstance3D.new()
    item.name = name
    var shape := CylinderMesh.new()
    shape.height = 0.025
    shape.top_radius = 0.18
    shape.bottom_radius = 0.18
    shape.radial_segments = 10
    item.mesh = shape
    item.position = location
    item.rotation.z = PI / 2.0
    item.material_override = _hub_finish
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(item)

func _wheel_face(label: String, sign: float, axle: float) -> void:
    var axle_name: String = "Front" if axle < 0.0 else "Rear"
    var center := Vector3(sign * 0.935, 0.36, axle)
    var face := MeshInstance3D.new()
    face.name = axle_name + "WheelFace_" + label
    var disc := CylinderMesh.new()
    disc.top_radius = 0.255
    disc.bottom_radius = 0.255
    disc.height = 0.018
    disc.radial_segments = 12
    face.mesh = disc
    face.position = center
    face.rotation.z = PI / 2.0
    face.material_override = _trim
    face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(face)
    # Five simple radial spokes, all within the wheel's original 0.34 m
    # radius; avoid a second transparent material on crowded Android roads.
    for spoke in range(5):
        var angle: float = TAU * float(spoke) / 5.0
        var spoke_item := MeshInstance3D.new()
        spoke_item.name = "%sWheelSpoke_%s_%d" % [axle_name, label, spoke]
        var bar := BoxMesh.new()
        bar.size = Vector3(0.025, 0.048, 0.19)
        spoke_item.mesh = bar
        spoke_item.position = center + Vector3(sign * 0.017,
            sin(angle) * 0.11, cos(angle) * 0.11)
        spoke_item.rotation.x = -angle
        spoke_item.material_override = _hub_finish
        spoke_item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(spoke_item)

func _build_details() -> void:
    # Slim hood/trunk shoulders create an actual car silhouette instead
    # of a monolithic tall cube. All pieces remain presentation-only.
    _box("Hood", Vector3(0, 0.83, -1.04), Vector3(1.53, 0.10, 0.77), _paint)
    _box("Trunk", Vector3(0, 0.83, 1.16), Vector3(1.52, 0.10, 0.54), _paint)
    # CAR-ART-05B: body shoulder lines and a subdued hood intake make the
    # low-poly sedan readable from the elevated third-person camera.
    for side in [-1, 1]:
        var side_f: float = float(side)
        var side_name: String = "L" if side < 0 else "R"
        _box("HoodShoulder_" + side_name, Vector3(side_f * 0.68, 0.866, -1.05),
            Vector3(0.095, 0.055, 0.77), _paint)
        _box("TrunkShoulder_" + side_name, Vector3(side_f * 0.68, 0.875, 1.16),
            Vector3(0.095, 0.055, 0.54), _paint)
    # The roof bridges the tapered cabin; glass sits within its silhouette.
    _box("Roof", Vector3(0, 1.283, 0.13), Vector3(1.19, 0.08, 1.00), _paint)
    # Preserve the old named roof pieces for art contracts, but recess
    # them into painted roof edges. Dark raised bars looked like a cage.
    _box("RoofFrontLip", Vector3(0, 1.25, -0.345),
        Vector3(1.12, 0.035, 0.06), _paint)
    _box("RoofRearLip", Vector3(0, 1.25, 0.605),
        Vector3(1.12, 0.035, 0.06), _paint)
    _box("Windscreen", Vector3(0, 1.035, -0.607),
        Vector3(1.12, 0.36, 0.035), _glass, -0.53)
    _box("RearGlass", Vector3(0, 1.037, 0.755),
        Vector3(1.10, 0.35, 0.035), _glass, 0.45)
    for side in [-1, 1]:
        var s: float = float(side)
        var label: String = "L" if side < 0 else "R"
        # Keep both panes inset from the cabin corner instead of floating
        # outside its tapered body. Small frames separate the two doors.
        _box("FrontSideWindow_" + label, Vector3(s * 0.632, 1.115, -0.265),
            Vector3(0.018, 0.205, 0.49), _glass)
        _box("RearSideWindow_" + label, Vector3(s * 0.632, 1.115, 0.405),
            Vector3(0.018, 0.205, 0.39), _glass)
        # Opaque window lower rail separates body paint from thin glass.
        _box("WindowSill_" + label, Vector3(s * 0.67, 0.998, 0.07),
            Vector3(0.035, 0.035, 1.25), _trim)
        # Three-piece compact mirror: a short arm attached at the door,
        # dark housing and inset rear-facing metallic glass. Preserve the
        # legacy Mirror_L/R names for visual contracts.
        # Mirror shell visibly projects beyond the door side, with real
        # rear-facing reflective glass. All presentation-only.
        _box("MirrorMount_" + label, Vector3(s * 0.747, 0.997, -0.60),
            Vector3(0.115, 0.045, 0.06), _trim)
        _box("Mirror_" + label, Vector3(s * 0.847, 1.005, -0.61),
            Vector3(0.145, 0.10, 0.135), _paint)
        _box("MirrorGlass_" + label, Vector3(s * 0.847, 1.012, -0.535),
            Vector3(0.119, 0.078, 0.012), _mirror_glass)
        _box("FrontLamp_" + label, Vector3(s * 0.56, 0.69, -1.483),
            Vector3(0.32, 0.13, 0.035), _headlamp)
        _box("RearLamp_" + label, Vector3(s * 0.56, 0.68, 1.485),
            Vector3(0.28, 0.14, 0.035), _tail)
        _box("FrontLampBrow_" + label, Vector3(s * 0.56, 0.765, -1.486),
            Vector3(0.34, 0.025, 0.045), _trim)
        _box("RearLampBorder_" + label, Vector3(s * 0.56, 0.77, 1.48),
            Vector3(0.30, 0.023, 0.043), _trim)
        _box("DoorHandle_" + label, Vector3(s * 0.806, 0.83, 0.0),
            Vector3(0.019, 0.035, 0.17), _metal)
        _hub("FrontHub_" + label, Vector3(s * 0.932, 0.36, -0.95))
        _hub("RearHub_" + label, Vector3(s * 0.932, 0.36, 0.95))
    _box("FrontGrille", Vector3(0, 0.48, -1.485),
        Vector3(0.73, 0.18, 0.04), _trim)
    # CAR-ART-05C: recessed grille and bounded trim distinguish the nose
    # from the tail without exceeding the existing traffic collider.
    _box("GrilleSurroundTop", Vector3(0, 0.588, -1.488),
        Vector3(0.83, 0.028, 0.035), _metal)
    _box("GrilleSurroundBottom", Vector3(0, 0.378, -1.488),
        Vector3(0.83, 0.026, 0.035), _metal)
    for side in [-1, 1]:
        var sign: float = float(side)
        var label: String = "L" if side < 0 else "R"
        _box("GrilleSide_" + label, Vector3(sign * 0.408, 0.48, -1.489),
            Vector3(0.024, 0.19, 0.035), _metal)
    _box("FrontBumper", Vector3(0, 0.30, -1.505),
        Vector3(1.53, 0.12, 0.065), _metal)
    _box("RearBumper", Vector3(0, 0.30, 1.505),
        Vector3(1.53, 0.12, 0.065), _metal)
    _box("RearTrunkLip", Vector3(0, 0.90, 1.424),
        Vector3(1.43, 0.028, 0.095), _paint)
    _box("RearTailPanel", Vector3(0, 0.61, 1.497),
        Vector3(0.73, 0.15, 0.025), _trim)
    _box("RearLowerValance", Vector3(0, 0.255, 1.507),
        Vector3(1.28, 0.055, 0.043), _trim)
    _box("LicensePlateFront", Vector3(0, 0.34, -1.545),
        Vector3(0.39, 0.10, 0.016), _metal)
    _box("LicensePlateRear", Vector3(0, 0.34, 1.545),
        Vector3(0.39, 0.10, 0.016), _metal)
    # Door seams, pillars, wheel arch accents and running boards add a
    # recognizable sedan profile while keeping physics entirely unchanged.
    _box("FrontAirIntake", Vector3(0.0, 0.29, -1.548),
        Vector3(0.68, 0.085, 0.02), _trim)
    _box("RearNumberFrame", Vector3(0.0, 0.50, 1.529),
        Vector3(0.52, 0.19, 0.027), _trim)
    for side in [-1, 1]:
        var s: float = float(side)
        var label: String = "L" if side < 0 else "R"
        _box("CabinCenterPillar_" + label, Vector3(s * 0.691, 1.055, 0.12),
            Vector3(0.038, 0.34, 0.065), _trim)
        _box("RunningBoard_" + label, Vector3(s * 0.79, 0.35, 0.0),
            Vector3(0.055, 0.10, 1.62), _trim)
        _box("Waistline_" + label, Vector3(s * 0.812, 0.82, 0.02),
            Vector3(0.018, 0.025, 2.10), _metal)
        _box("DoorSeam_" + label, Vector3(s * 0.814, 0.70, 0.2),
            Vector3(0.02, 0.38, 0.024), _trim)
        # Two legible door outlines: narrow seams, not painted-on blocks.
        _box("FrontDoorLowerLine_" + label, Vector3(s * 0.816, 0.47, -0.40),
            Vector3(0.016, 0.018, 0.68), _trim)
        _box("RearDoorLowerLine_" + label, Vector3(s * 0.816, 0.47, 0.57),
            Vector3(0.016, 0.018, 0.57), _trim)
        _box("FrontDoorHandle_" + label, Vector3(s * 0.819, 0.82, -0.41),
            Vector3(0.018, 0.029, 0.13), _metal)
        _box("RearDoorHandle_" + label, Vector3(s * 0.819, 0.82, 0.46),
            Vector3(0.018, 0.029, 0.13), _metal)
        for axle in [-0.95, 0.95]:
            var axle_name: String = "Front" if axle < 0.0 else "Rear"
            _box(axle_name + "Arch_" + label, Vector3(s * 0.794, 0.59, axle),
                Vector3(0.06, 0.045, 0.69), _trim)
        _box("FogLamp_" + label, Vector3(s * 0.67, 0.37, -1.535),
            Vector3(0.16, 0.065, 0.025), _headlamp)
        # Visual-only wheel face: a centered rim and five spokes sit on
        # the original wheel location. No wheel transforms or physics edits.
        for axle in [-0.95, 0.95]:
            _wheel_face(label, s, axle)
    _box("HoodCenterCrease", Vector3(0, 0.896, -1.09),
        Vector3(0.025, 0.014, 0.66), _metal)
    _box("RearWindowBrakeStrip", Vector3(0, 1.275, 0.54),
        Vector3(0.43, 0.035, 0.04), _tail)
    # Simple grille slats and side reflectors improve front/back recognition
    # in moving traffic without high-poly imported meshes or new colliders.
    for index in range(3):
        _box("GrilleSlat_%d" % index, Vector3(0, 0.42 + float(index) * 0.045, -1.545),
            Vector3(0.58, 0.017, 0.013), _metal)
    _box("FrontBadge", Vector3(0, 0.74, -1.492),
        Vector3(0.15, 0.065, 0.02), _metal)
    for side in [-1, 1]:
        var edge: float = float(side)
        var tag: String = "L" if side < 0 else "R"
        _box("FrontSideMarker_" + tag, Vector3(edge * 0.803, 0.54, -1.34),
            Vector3(0.024, 0.085, 0.15), _headlamp)
        _box("RearSideReflector_" + tag, Vector3(edge * 0.803, 0.54, 1.32),
            Vector3(0.024, 0.075, 0.15), _tail)
