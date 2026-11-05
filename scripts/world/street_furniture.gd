extends Node3D
## Lightweight procedural street furniture. Visual only; no physics blockers.

var _signal_controller: CivicTrafficSignalController
var _signal_lamps: Array[Dictionary] = []
var _lamp_materials: Array[Array] = []
var _last_aspects: Array[String] = []

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
    _bench(Vector3(9.0, 0, -19.0))
    _bench(Vector3(-9.0, 0, 19.0))

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
    var materials: Array = []
    for lamp_index in range(3):
        var color: Color = [Color.RED, Color.YELLOW, Color.GREEN][lamp_index]
        var unlit := _material(color.darkened(0.83))
        var lit := _material(color)
        lit.emission_enabled = true
        lit.emission = color
        lit.emission_energy_multiplier = 1.3
        materials.append([unlit, lit])
        lights[lamp_index].material_override = unlit
    _lamp_materials.append(materials)
    _last_aspects.append("")
    _signal_lamps.append({"approach": ["N", "E", "S", "W"][index], "lamps": lights})

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
    _sphere(root, "LowerCanopy", Vector3(0, 2.85, 0), 1.15, Color(0.18, 0.39, 0.23))
    _sphere(root, "UpperCanopy", Vector3(0.25, 3.65, 0.1), 1.05, Color(0.27, 0.55, 0.30))

func _bench(location: Vector3) -> void:
    var root := Node3D.new()
    root.name = "SidewalkBench"
    root.position = location
    add_child(root)
    var wood := Color(0.48, 0.28, 0.14)
    var metal := Color(0.20, 0.23, 0.26)
    _box(root, "Seat", Vector3(0, 0.55, 0), Vector3(1.7, 0.13, 0.55), wood)
    _box(root, "Backrest", Vector3(0, 1.0, 0.25), Vector3(1.7, 0.7, 0.12), wood)
    _box(root, "LeftLeg", Vector3(-0.65, 0.26, 0), Vector3(0.12, 0.52, 0.12), metal)
    _box(root, "RightLeg", Vector3(0.65, 0.26, 0), Vector3(0.12, 0.52, 0.12), metal)

func _process(_delta: float) -> void:
    if _signal_controller == null:
        return
    for signal_index in range(_signal_lamps.size()):
        var data: Dictionary = _signal_lamps[signal_index]
        var aspect: String = _signal_controller.aspect_for_approach(data["approach"])
        if aspect == _last_aspects[signal_index]:
            continue
        _last_aspects[signal_index] = aspect
        var lamps: Array = data["lamps"]
        for index in range(lamps.size()):
            var lit: bool = aspect == ["red", "amber", "green"][index]
            lamps[index].material_override = _lamp_materials[signal_index][index][1 if lit else 0]
