class_name CivicWorld002FacadeIdentity
extends RefCounted
## WORLD-002A: visual-only attachments to existing, physically grounded
## building boxes. No additional collision shapes or physics bodies.
static func _paint(color: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.9
    return result

static func _box(parent: Node3D, name: String, at: Vector3,
        size: Vector3, paint: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    mesh.position = at
    mesh.material_override = paint
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)

static func build(parent: Node3D, shape: Vector3, style: String) -> void:
    if parent == null:
        return
    var frontage := Node3D.new()
    frontage.name = "World002Facade"
    parent.add_child(frontage)
    var awning_color: Color = Color(0.64, 0.27, 0.21)
    var band_color: Color = Color(0.90, 0.76, 0.53)
    match style:
        "residential":
            awning_color = Color(0.26, 0.43, 0.49)
            band_color = Color(0.74, 0.79, 0.76)
        "civic":
            awning_color = Color(0.30, 0.46, 0.36)
            band_color = Color(0.86, 0.84, 0.66)
        "mixed":
            awning_color = Color(0.42, 0.32, 0.50)
            band_color = Color(0.79, 0.74, 0.83)
    var trim := _paint(band_color)
    var roof := _paint(awning_color)
    # Upper cornices and a shallow recessed-looking front arcade vary
    # the silhouette without ever projecting into a street or footpath.
    _box(frontage, "Parapet", Vector3(0, shape.y * 0.5 + 0.32, 0),
        Vector3(shape.x + 0.3, 0.64, shape.z + 0.3), roof)
    _box(frontage, "FrontageBand",
        Vector3(0, -shape.y * 0.5 + 2.65, -shape.z * 0.5 - 0.035),
        Vector3(shape.x, 0.22, 0.10), trim)
    if style == "market" or style == "mixed":
        for index in range(2):
            var x: float = (-0.22 if index == 0 else 0.22) * shape.x
            _box(frontage, "ShopAwning_%d" % index,
                Vector3(x, -shape.y * 0.5 + 2.5, -shape.z * 0.5 - 0.35),
                Vector3(shape.x * 0.36, 0.10, 0.65), roof)
    elif style == "residential":
        for index in range(2):
            var x: float = (-0.25 if index == 0 else 0.25) * shape.x
            _box(frontage, "Balcony_%d" % index,
                Vector3(x, -shape.y * 0.5 + 3.25, -shape.z * 0.5 - 0.24),
                Vector3(shape.x * 0.32, 0.12, 0.42), trim)
    else:
        _box(frontage, "CivicEntranceCanopy",
            Vector3(0, -shape.y * 0.5 + 2.6, -shape.z * 0.5 - 0.25),
            Vector3(shape.x * 0.55, 0.14, 0.5), roof)
