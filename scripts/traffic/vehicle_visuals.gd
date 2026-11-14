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
var _paint: StandardMaterial3D
var _glass: StandardMaterial3D
var _mirror_glass: StandardMaterial3D
var _trim: StandardMaterial3D
var _metal: StandardMaterial3D
var _rubber: StandardMaterial3D
var _hub_finish: StandardMaterial3D
var _headlamp: StandardMaterial3D
var _tail: StandardMaterial3D
var _color_slot: int = 0
var _braking: bool = false

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
    _headlamp.emission_enabled = true
    _headlamp.emission = Color(0.36, 0.34, 0.22)
    _tail.emission_enabled = true
    _tail.emission = Color(0.24, 0.015, 0.015)
    _reshape_legacy()
    _build_details()

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
        # A tapered six-sided cabin replaces the rectangular shoebox roof.
        # Roof pillars slope inwards and the front/rear glazing tilts back.
        cabin.mesh = _tapered_cabin()
        cabin.position = Vector3(0, 1.035, 0.10)
        cabin.material_override = _paint

func _tapered_cabin() -> ArrayMesh:
    var corners: Array[Vector3] = [
        Vector3(-0.675, -0.225, -0.75), Vector3(0.675, -0.225, -0.75),
        Vector3(0.675, -0.225, 0.78), Vector3(-0.675, -0.225, 0.78),
        Vector3(-0.58, 0.225, -0.46), Vector3(0.58, 0.225, -0.46),
        Vector3(0.58, 0.225, 0.53), Vector3(-0.58, 0.225, 0.53)
    ]
    var faces: Array = [
        [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3],
        [3, 7, 4, 0], [4, 7, 6, 5], [0, 1, 2, 3]
    ]
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for face in faces:
        for offset in [0, 1, 2, 0, 2, 3]:
            surface.add_vertex(corners[int(face[offset])])
    surface.generate_normals()
    return surface.commit()

func set_lane_variant(lane_id: int) -> void:
    # The existing lane is deterministic and saved with route state.
    # Do NOT use the simulation RNG for cosmetic choices.
    _color_slot = posmod(lane_id, PALETTE.size())
    if _paint != null:
        _paint.albedo_color = PALETTE[_color_slot]

func color_variant() -> int:
    return _color_slot

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

func _build_details() -> void:
    # Slim hood/trunk shoulders create an actual car silhouette instead
    # of a monolithic tall cube. All pieces remain presentation-only.
    _box("Hood", Vector3(0, 0.83, -1.04), Vector3(1.53, 0.10, 0.77), _paint)
    _box("Trunk", Vector3(0, 0.83, 1.16), Vector3(1.52, 0.10, 0.54), _paint)
    # The roof bridges the tapered cabin; glass sits within its silhouette.
    _box("Roof", Vector3(0, 1.283, 0.13), Vector3(1.19, 0.08, 1.00), _paint)
    _box("Windscreen", Vector3(0, 1.035, -0.607),
        Vector3(1.12, 0.36, 0.035), _glass, -0.53)
    _box("RearGlass", Vector3(0, 1.037, 0.755),
        Vector3(1.10, 0.35, 0.035), _glass, 0.45)
    for side in [-1, 1]:
        var s: float = float(side)
        var label: String = "L" if side < 0 else "R"
        # Keep both panes inset from the cabin corner instead of floating
        # outside its tapered body. Small frames separate the two doors.
        _box("FrontSideWindow_" + label, Vector3(s * 0.673, 1.04, -0.265),
            Vector3(0.024, 0.235, 0.49), _glass)
        _box("RearSideWindow_" + label, Vector3(s * 0.673, 1.04, 0.405),
            Vector3(0.024, 0.235, 0.39), _glass)
        # Three-piece compact mirror: a short arm attached at the door,
        # dark housing and inset rear-facing metallic glass. Preserve the
        # legacy Mirror_L/R names for visual contracts.
        _box("MirrorMount_" + label, Vector3(s * 0.743, 0.972, -0.62),
            Vector3(0.115, 0.055, 0.085), _trim)
        _box("Mirror_" + label, Vector3(s * 0.811, 1.00, -0.65),
            Vector3(0.145, 0.105, 0.165), _trim)
        _box("MirrorGlass_" + label, Vector3(s * 0.811, 1.008, -0.56),
            Vector3(0.119, 0.075, 0.012), _mirror_glass)
        _box("FrontLamp_" + label, Vector3(s * 0.56, 0.69, -1.483),
            Vector3(0.32, 0.13, 0.035), _headlamp)
        _box("RearLamp_" + label, Vector3(s * 0.56, 0.68, 1.485),
            Vector3(0.28, 0.14, 0.035), _tail)
        _box("DoorHandle_" + label, Vector3(s * 0.806, 0.83, 0.0),
            Vector3(0.019, 0.035, 0.17), _metal)
        _hub("FrontHub_" + label, Vector3(s * 0.932, 0.36, -0.95))
        _hub("RearHub_" + label, Vector3(s * 0.932, 0.36, 0.95))
    _box("FrontGrille", Vector3(0, 0.48, -1.485),
        Vector3(0.73, 0.18, 0.04), _trim)
    _box("FrontBumper", Vector3(0, 0.30, -1.505),
        Vector3(1.53, 0.12, 0.065), _metal)
    _box("RearBumper", Vector3(0, 0.30, 1.505),
        Vector3(1.53, 0.12, 0.065), _metal)
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
        for axle in [-0.95, 0.95]:
            var axle_name: String = "Front" if axle < 0.0 else "Rear"
            _box(axle_name + "Arch_" + label, Vector3(s * 0.794, 0.59, axle),
                Vector3(0.06, 0.045, 0.69), _trim)
        _box("FogLamp_" + label, Vector3(s * 0.67, 0.37, -1.535),
            Vector3(0.16, 0.065, 0.025), _headlamp)
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
