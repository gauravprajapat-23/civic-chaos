class_name CivicLowPolyCharacter
extends RefCounted
## Original low-poly city resident art. Visual-only; NEVER changes collider
## layers, locomotion, interaction policy, or physics shape size.
## The four named limb pivot nodes match legacy player/NPC walk animation.

static func _mat(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88
    return material

static func _box(parent: Node3D, name: String, at: Vector3, size: Vector3,
        material: Material) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    visual.name = name
    visual.position = at
    var box := BoxMesh.new()
    box.size = size
    visual.mesh = box
    visual.material_override = material
    parent.add_child(visual)
    return visual

static func _sphere(parent: Node3D, name: String, at: Vector3, radius: float,
        material: Material) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    visual.name = name
    visual.position = at
    var sphere := SphereMesh.new()
    sphere.radius = radius
    sphere.height = radius * 2.0
    sphere.radial_segments = 8
    sphere.rings = 4
    visual.mesh = sphere
    visual.material_override = material
    parent.add_child(visual)
    return visual

## y_origin converts a ground-based design into the player scene's
## existing Visual pivot (y=.9). For walkers/owner/marshal pass 0.
static func build(parent: Node3D, clothing: Color, skin: Color, pants: Color,
        accent: Color, y_origin: float = 0.0) -> Dictionary:
    var shirt := _mat(clothing)
    var skin_mat := _mat(skin)
    var trouser := _mat(pants)
    var trim := _mat(accent)
    var hair := _mat(Color(0.13, 0.11, 0.12))
    var shoe := _mat(Color(0.105, 0.13, 0.17))
    var eye := _mat(Color(0.10, 0.10, 0.12))
    var clothing_shadow := _mat(clothing.darkened(0.25))

    var torso := Node3D.new()
    torso.name = "Torso"
    torso.position.y = y_origin + 1.18
    parent.add_child(torso)
    _box(torso, "Shirt", Vector3.ZERO, Vector3(0.57, 0.65, 0.31), shirt)
    _box(torso, "Shoulders", Vector3(0, 0.22, 0), Vector3(0.66, 0.16, 0.34), shirt)
    _box(torso, "Collar", Vector3(0, 0.34, -0.08), Vector3(0.25, 0.08, 0.19), trim)
    _box(torso, "Hem", Vector3(0, -0.32, 0), Vector3(0.53, 0.09, 0.32), clothing_shadow)
    _box(parent, "Hips", Vector3(0, y_origin + 0.79, 0), Vector3(0.48, 0.24, 0.3), trouser)

    var neck := _box(parent, "Neck", Vector3(0, y_origin + 1.55, 0),
        Vector3(0.19, 0.18, 0.19), skin_mat)
    neck.visible = true
    var head := Node3D.new()
    head.name = "Head"
    head.position = Vector3(0, y_origin + 1.73, 0)
    parent.add_child(head)
    _box(head, "Face", Vector3(0, 0, 0), Vector3(0.39, 0.43, 0.34), skin_mat)
    _box(head, "HairCap", Vector3(0, 0.235, 0.005), Vector3(0.43, 0.15, 0.37), hair)
    _box(head, "HairFringe", Vector3(0, 0.155, -0.19), Vector3(0.42, 0.10, 0.055), hair)
    _box(head, "LeftEar", Vector3(-0.21, -0.015, 0), Vector3(0.07, 0.15, 0.11), skin_mat)
    _box(head, "RightEar", Vector3(0.21, -0.015, 0), Vector3(0.07, 0.15, 0.11), skin_mat)
    _box(head, "EyeL", Vector3(-0.095, 0.025, -0.178), Vector3(0.047, 0.045, 0.025), eye)
    _box(head, "EyeR", Vector3(0.095, 0.025, -0.178), Vector3(0.047, 0.045, 0.025), eye)
    _box(head, "Nose", Vector3(0, -0.072, -0.19), Vector3(0.07, 0.09, 0.07), skin_mat)

    var limbs: Dictionary = {}
    for side in [-1, 1]:
        var left: bool = side < 0
        var prefix := "Left" if left else "Right"
        var arm := Node3D.new()
        arm.name = prefix + "Arm"
        arm.position = Vector3(float(side) * 0.36, y_origin + 1.38, 0)
        parent.add_child(arm)
        _box(arm, "Sleeve", Vector3(0, -0.16, 0), Vector3(0.20, 0.38, 0.25), shirt)
        _box(arm, "Forearm", Vector3(0, -0.43, 0), Vector3(0.16, 0.22, 0.18), skin_mat)
        _box(arm, "Hand", Vector3(0, -0.58, 0), Vector3(0.16, 0.16, 0.17), skin_mat)
        var leg := Node3D.new()
        leg.name = prefix + "Leg"
        leg.position = Vector3(float(side) * 0.15, y_origin + 0.74, 0)
        parent.add_child(leg)
        _box(leg, "Trouser", Vector3(0, -0.30, 0), Vector3(0.21, 0.54, 0.25), trouser)
        _box(leg, "Shoe", Vector3(0, -0.64, -0.085), Vector3(0.24, 0.15, 0.37), shoe)
        limbs[prefix + "Arm"] = arm
        limbs[prefix + "Leg"] = leg
    return limbs
