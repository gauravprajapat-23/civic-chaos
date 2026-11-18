class_name CivicMotorcycleRiderRig
extends Node3D
## VEHICLE-RIDE-05B: visual-only rider parented to the bike VisualRig.
## All positions use bike-local metres; no collision bodies or player teleporting.
const LIMB_RADIUS: float = 0.075
var _fork: Node3D
var _grips: Array[Marker3D] = []
var _feet: Array[Marker3D] = []
var _segments: Array[MeshInstance3D] = []
var _joints: Array[MeshInstance3D] = []
var _hip: Vector3 = Vector3(0, 1.30, 0.43)
var _skin: Material
var _shirt: Material
var _pants: Material

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.83
    return mat

func _box(name: String, size: Vector3, at: Vector3, mat: Material) -> void:
    var part := MeshInstance3D.new()
    part.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.position = at
    part.material_override = mat
    add_child(part)

func _segment(name: String, mat: Material, width: float) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = name
    var mesh := CylinderMesh.new()
    mesh.top_radius = width
    mesh.bottom_radius = width
    mesh.height = 1.0
    part.mesh = mesh
    part.material_override = mat
    add_child(part)
    return part

func _joint(name: String, mat: Material, radius: float) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    part.mesh = mesh
    part.material_override = mat
    add_child(part)
    return part

func _point_segment(part: MeshInstance3D, a: Vector3, b: Vector3) -> void:
    var axis := b - a
    if axis.length_squared() < 0.000001:
        part.visible = false
        return
    part.visible = true
    part.position = (a + b) * 0.5
    part.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
    part.scale = Vector3(1, axis.length(), 1)

## Stable two-bone elbow/knee. Clamp unreachable targets and use a fixed
## anatomical bend direction rather than an unstable pole near straight limbs.
static func bend_joint(a: Vector3, b: Vector3, upper: float,
        lower: float, pole: Vector3) -> Vector3:
    var ray := b - a
    var length: float = maxf(ray.length(), 0.0001)
    var direction := ray / length
    var reach: float = clampf(length, absf(upper - lower) + 0.001,
        upper + lower - 0.001)
    var along: float = (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
    var height: float = sqrt(maxf(0.0, upper * upper - along * along))
    var lateral := pole - direction * pole.dot(direction)
    if lateral.length_squared() < 0.00001:
        lateral = direction.cross(Vector3.UP)
    if lateral.length_squared() < 0.00001:
        lateral = Vector3.RIGHT
    return a + direction * along + lateral.normalized() * height

func configure(fork: Node3D) -> void:
    _fork = fork
    _skin = _material(Color(0.72, 0.48, 0.33))
    _shirt = _material(Color(0.15, 0.39, 0.74))
    _pants = _material(Color(0.19, 0.24, 0.35))
    _box("SeatedHips", Vector3(0.44, 0.20, 0.32), _hip, _pants)
    _box("RiderTorso", Vector3(0.54, 0.63, 0.30),
        Vector3(0, 1.65, 0.28), _shirt)
    _box("RiderNeck", Vector3(0.16, 0.13, 0.16),
        Vector3(0, 2.02, 0.24), _skin)
    _box("RiderHead", Vector3(0.37, 0.40, 0.35),
        Vector3(0, 2.24, 0.23), _skin)
    _box("RiderHair", Vector3(0.39, 0.10, 0.36),
        Vector3(0, 2.46, 0.23), _material(Color(0.13, 0.11, 0.12)))
    for side in [-1.0, 1.0]:
        var prefix := "Left" if side < 0.0 else "Right"
        var grip := Marker3D.new()
        grip.name = prefix + "GripTarget"
        grip.position = Vector3(side * 0.43, 0.63, 0.025)
        fork.add_child(grip)
        _grips.append(grip)
        var foot := Marker3D.new()
        foot.name = prefix + "FootpegTarget"
        foot.position = Vector3(side * 0.43, 0.70, 0.32)
        add_child(foot)
        _feet.append(foot)
        _segments.append(_segment(prefix + "UpperArm", _shirt, 0.105))
        _segments.append(_segment(prefix + "Forearm", _skin, LIMB_RADIUS))
        _segments.append(_segment(prefix + "Thigh", _pants, 0.115))
        _segments.append(_segment(prefix + "Shin", _pants, 0.09))
        _joints.append(_joint(prefix + "Elbow", _skin, 0.09))
        _joints.append(_joint(prefix + "Hand", _skin, 0.105))
        _joints.append(_joint(prefix + "Knee", _pants, 0.115))
        _joints.append(_joint(prefix + "Boot", _material(Color(0.10, 0.13, 0.17)), 0.13))
    update_targets(1.0)

func update_targets(blend: float = 1.0) -> void:
    if not is_instance_valid(_fork) or _grips.size() != 2:
        return
    for i in range(2):
        var side: float = -1.0 if i == 0 else 1.0
        var shoulder := Vector3(side * 0.32, 1.84, 0.23)
        var hand := to_local(_grips[i].global_position)
        var elbow := bend_joint(shoulder, hand, 0.44, 0.44,
            Vector3(side * 0.55, -0.25, 0.05))
        var hip := _hip + Vector3(side * 0.15, 0, -0.02)
        var boot := _feet[i].position
        var knee := bend_joint(hip, boot, 0.58, 0.59,
            Vector3(side * 0.20, 0.05, -0.9))
        var n := i * 4
        _point_segment(_segments[n], shoulder, elbow)
        _point_segment(_segments[n + 1], elbow, hand)
        _point_segment(_segments[n + 2], hip, knee)
        _point_segment(_segments[n + 3], knee, boot)
        _joints[n].position = elbow
        _joints[n + 1].position = hand
        _joints[n + 2].position = knee
        _joints[n + 3].position = boot
