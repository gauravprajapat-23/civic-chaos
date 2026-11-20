class_name CivicVehicleExteriorIdentity
extends RefCounted
## VEH-ART-08: unmistakable low-poly street-car identity, visuals only.
## No colliders, traffic or RNG. Fit within current 1.6m x 2.94m shell.
static func _box(parent: Node3D, part_name: String, pos: Vector3,
        dimensions: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    part.mesh = BoxMesh.new()
    (part.mesh as BoxMesh).size = dimensions
    part.position = pos
    part.material_override = material
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(part)
    return part

static func build(parent: Node3D, body_paint: Material,
        metal: Material, dark_trim: Material, tail_lamp: Material) -> void:
    if parent == null or parent.has_node("BodyDesign08"):
        return
    var group := Node3D.new()
    group.name = "BodyDesign08"
    parent.add_child(group)
    var plate := StandardMaterial3D.new()
    plate.albedo_color = Color(0.94, 0.92, 0.81)
    plate.roughness = 0.88
    var black := StandardMaterial3D.new()
    black.albedo_color = Color(0.10, 0.12, 0.14)
    black.roughness = 0.70
    # Nose shape: inset lower intake, vertical air intakes and slender
    # chrome strips; keep bright headlamps visible from traffic camera.
    _box(group, "FrontLowerIntake", Vector3(0, 0.303, -1.485),
        Vector3(0.68, 0.12, 0.019), dark_trim)
    _box(group, "FrontPlate", Vector3(0, 0.525, -1.516),
        Vector3(0.40, 0.12, 0.012), plate)
    _box(group, "FrontPlateStripe", Vector3(0, 0.526, -1.526),
        Vector3(0.25, 0.017, 0.008), black)
    for side in [-1.0, 1.0]:
        var label: String = "L" if side < 0.0 else "R"
        _box(group, "FogLamp_" + label, Vector3(side * 0.60, 0.345, -1.51),
            Vector3(0.15, 0.075, 0.020), metal)
        _box(group, "FrontAirIntake_" + label, Vector3(side * 0.735, 0.37, -1.49),
            Vector3(0.045, 0.16, 0.026), dark_trim)
        # Upper/lower sill layering breaks up slab-like side views.
        _box(group, "SideRocker_" + label, Vector3(side * 0.789, 0.37, 0),
            Vector3(0.020, 0.065, 1.79), dark_trim)
        _box(group, "DoorBeltAccent_" + label, Vector3(side * 0.796, 0.94, 0.10),
            Vector3(0.022, 0.018, 1.25), metal)
        _box(group, "RearReflector_" + label, Vector3(side * 0.64, 0.40, 1.50),
            Vector3(0.18, 0.055, 0.014), tail_lamp)
        _box(group, "RearMudflap_" + label, Vector3(side * 0.68, 0.19, 1.26),
            Vector3(0.18, 0.17, 0.018), dark_trim)
    _box(group, "RearPlate", Vector3(0, 0.54, 1.516),
        Vector3(0.41, 0.13, 0.015), plate)
    _box(group, "RearPlateStripe", Vector3(0, 0.54, 1.526),
        Vector3(0.25, 0.016, 0.009), black)
    _box(group, "TrunkBadge", Vector3(0, 0.74, 1.505),
        Vector3(0.18, 0.035, 0.015), metal)
    _box(group, "RoofAntennaBase", Vector3(0, 1.350, 0.65),
        Vector3(0.14, 0.055, 0.17), body_paint)
    _box(group, "RoofAntenna", Vector3(0, 1.47, 0.69),
        Vector3(0.025, 0.22, 0.025), dark_trim)

## Existing near/mid/far visual LOD must also cull newly added details.
static func apply_lod(parent: Node3D, level: int) -> void:
    var group: Node3D = parent.get_node_or_null("BodyDesign08") as Node3D
    if group == null:
        return
    # Far view leaves legacy roof/chassis/signal lights visible.
    group.visible = level != 2
    for item in group.get_children():
        if item is VisualInstance3D:
            var keep_at_mid: bool = str(item.name) in [
                "FrontLowerIntake", "FrontPlate", "RearPlate",
                "SideRocker_L", "SideRocker_R"
            ]
            (item as VisualInstance3D).visible = level == 0 or (
                level == 1 and keep_at_mid)
