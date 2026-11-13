class_name CivicVehicleVisuals
extends Node3D
## ART-CAR-01: light-weight, low-poly sedan presentation layered on the
## unchanged CivicVehicleAgent collision/route. No physics, RNG or gameplay.
## -Z is the car front, matching the road-following transform.
const PALETTE: Array[Color] = [
    Color(0.10, 0.39, 0.74),
    Color(0.71, 0.15, 0.14),
    Color(0.79, 0.82, 0.83),
    Color(0.19, 0.24, 0.29),
    Color(0.17, 0.55, 0.43)
]
var _paint: StandardMaterial3D
var _glass: StandardMaterial3D
var _trim: StandardMaterial3D
var _metal: StandardMaterial3D
var _rubber: StandardMaterial3D
var _headlamp: StandardMaterial3D
var _tail: StandardMaterial3D
var _color_slot: int = 0

func _ready() -> void:
    _paint = _material(PALETTE[0], 0.36, 0.36)
    _glass = _material(Color(0.07, 0.18, 0.26), 0.13, 0.18)
    _trim = _material(Color(0.045, 0.06, 0.08), 0.72)
    _metal = _material(Color(0.58, 0.62, 0.67), 0.3, 0.54)
    _rubber = _material(Color(0.045, 0.05, 0.06), 0.95)
    _headlamp = _material(Color(0.95, 0.92, 0.69), 0.28)
    _tail = _material(Color(0.86, 0.075, 0.055), 0.3)
    _headlamp.emission_enabled = true
    _headlamp.emission = Color(0.65, 0.56, 0.28)
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
        var glass_frame := BoxMesh.new()
        glass_frame.size = Vector3(1.34, 0.45, 1.43)
        cabin.mesh = glass_frame
        cabin.position = Vector3(0, 1.035, 0.10)
        cabin.material_override = _paint

func set_lane_variant(lane_id: int) -> void:
    # The existing lane is deterministic and saved with route state.
    # Do NOT use the simulation RNG for cosmetic choices.
    _color_slot = posmod(lane_id, PALETTE.size())
    if _paint != null:
        _paint.albedo_color = PALETTE[_color_slot]

func color_variant() -> int:
    return _color_slot

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
    item.material_override = _metal
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(item)

func _build_details() -> void:
    # Slim hood/trunk shoulders create an actual car silhouette instead
    # of a monolithic tall cube. All pieces remain presentation-only.
    _box("Hood", Vector3(0, 0.83, -1.04), Vector3(1.53, 0.10, 0.77), _paint)
    _box("Trunk", Vector3(0, 0.83, 1.16), Vector3(1.52, 0.10, 0.54), _paint)
    _box("Roof", Vector3(0, 1.29, 0.13), Vector3(1.27, 0.09, 0.95), _paint)
    _box("Windscreen", Vector3(0, 1.055, -0.63),
        Vector3(1.19, 0.41, 0.045), _glass, -0.37)
    _box("RearGlass", Vector3(0, 1.045, 0.80),
        Vector3(1.16, 0.40, 0.045), _glass, 0.34)
    for side in [-1, 1]:
        var s: float = float(side)
        var label: String = "L" if side < 0 else "R"
        _box("FrontSideWindow_" + label, Vector3(s * 0.689, 1.065, -0.25),
            Vector3(0.028, 0.29, 0.56), _glass)
        _box("RearSideWindow_" + label, Vector3(s * 0.689, 1.065, 0.45),
            Vector3(0.028, 0.29, 0.43), _glass)
        _box("Mirror_" + label, Vector3(s * 0.855, 0.99, -0.63),
            Vector3(0.23, 0.14, 0.21), _trim)
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
