extends Node3D
## Lightweight procedural street furniture. Visual only; no physics blockers.

var _signal_controller: CivicTrafficSignalController
var _signal_lamps: Array[Dictionary] = []

func configure_signals(controller: CivicTrafficSignalController) -> void:
    _signal_controller = controller

func _ready() -> void:
    for index in range(4):
        var side: int = index
        var position_value: Vector3 = [
            Vector3(6.5, 0, -7.5), Vector3(7.5, 0, 6.5),
            Vector3(-6.5, 0, 7.5), Vector3(-7.5, 0, -6.5)
        ][index]
        _traffic_light(side, position_value)
    for side in [-1, 1]:
        for distance in [-28.0, -16.0, 16.0, 28.0]:
            _streetlight(Vector3(float(side) * 7.2, 0, distance))
            _tree(Vector3(distance, 0, float(side) * 11.0))

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.8
    return material

func _box(parent: Node3D, label: String, location: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    part.position = location
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.material_override = _material(color)
    parent.add_child(part)
    return part

func _sphere(parent: Node3D, label: String, location: Vector3, radius: float, color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    part.position = location
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    part.mesh = mesh
    part.material_override = _material(color)
    parent.add_child(part)
    return part

func _traffic_light(index: int, location: Vector3) -> void:
    var root := Node3D.new()
    root.name = "TrafficSignal_%d" % index
    root.position = location
    add_child(root)
    _box(root, "Pole", Vector3(0, 2.1, 0), Vector3(0.15, 4.2, 0.15), Color(0.27, 0.29, 0.32))
    _box(root, "SignalCase", Vector3(0, 4.0, 0), Vector3(0.65, 1.6, 0.46), Color(0.12, 0.14, 0.16))
    var lights: Array[MeshInstance3D] = []
    for lamp_index in range(3):
        var color: Color = [Color.RED, Color.YELLOW, Color.GREEN][lamp_index]
        lights.append(_sphere(root, "Lamp_%d" % lamp_index, Vector3(0, 4.5 - float(lamp_index) * 0.48, -0.26), 0.16, color.darkened(0.8)))
    _signal_lamps.append({"approach": "N" if index % 2 == 0 else "E", "lamps": lights})

func _streetlight(location: Vector3) -> void:
    var root := Node3D.new()
    root.name = "Streetlight"
    root.position = location
    add_child(root)
    _box(root, "Pole", Vector3(0, 2.6, 0), Vector3(0.13, 5.2, 0.13), Color(0.31, 0.35, 0.39))
    _box(root, "Arm", Vector3(0.55, 5.1, 0), Vector3(1.2, 0.12, 0.12), Color(0.31, 0.35, 0.39))
    _box(root, "Lamp", Vector3(1.1, 5.02, 0), Vector3(0.45, 0.12, 0.32), Color(0.95, 0.90, 0.65))

func _tree(location: Vector3) -> void:
    var root := Node3D.new()
    root.name = "Tree"
    root.position = location
    add_child(root)
    _box(root, "Trunk", Vector3(0, 1.15, 0), Vector3(0.4, 2.3, 0.4), Color(0.40, 0.25, 0.14))
    _sphere(root, "Canopy", Vector3(0, 3.25, 0), 1.35, Color(0.20, 0.47, 0.25))

func _process(_delta: float) -> void:
    if _signal_controller == null:
        return
    for data in _signal_lamps:
        var aspect: String = _signal_controller.aspect_for_approach(data["approach"])
        var lamps: Array = data["lamps"]
        for index in range(lamps.size()):
            var lamp: MeshInstance3D = lamps[index]
            var color: Color = [Color.RED, Color.YELLOW, Color.GREEN][index]
            var lit: bool = aspect == ["red", "amber", "green"][index]
            lamp.material_override = _material(color if lit else color.darkened(0.83))
