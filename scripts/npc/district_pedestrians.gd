extends Node3D
## Lightweight, deterministic visual pedestrians for the district preview.
## This is a presentation layer, not the reservation-based crossing simulation.

@export var pedestrian_count: int = 8
@export var district_extent: float = 38.0
var _walkers: Array[Dictionary] = []
var _elapsed: float = 0.0

func _ready() -> void:
    var shirt_colors := [
        Color(0.82, 0.29, 0.24),
        Color(0.20, 0.53, 0.77),
        Color(0.31, 0.62, 0.39),
        Color(0.82, 0.66, 0.23)
    ]
    for index in range(pedestrian_count):
        var walker := Node3D.new()
        walker.name = "Pedestrian_%02d" % index
        add_child(walker)
        var color: Color = shirt_colors[index % shirt_colors.size()]
        _part(walker, "Torso", Vector3(0, 1.18, 0), Vector3(0.42, 0.62, 0.26), color)
        _part(walker, "Head", Vector3(0, 1.72, 0), Vector3(0.31, 0.33, 0.31), Color(0.70, 0.46, 0.31))
        var left_arm := _part(walker, "LeftArm", Vector3(-0.31, 1.13, 0), Vector3(0.15, 0.59, 0.18), color)
        var right_arm := _part(walker, "RightArm", Vector3(0.31, 1.13, 0), Vector3(0.15, 0.59, 0.18), color)
        var left_leg := _part(walker, "LeftLeg", Vector3(-0.12, 0.45, 0), Vector3(0.17, 0.78, 0.19), Color(0.17, 0.21, 0.28))
        var right_leg := _part(walker, "RightLeg", Vector3(0.12, 0.45, 0), Vector3(0.17, 0.78, 0.19), Color(0.17, 0.21, 0.28))
        _walkers.append({
            "root": walker, "arms": [left_arm, right_arm], "legs": [left_leg, right_leg],
            "phase": float(index) * 1.7, "speed": 1.0 + float(index % 3) * 0.22,
            "side": index % 4, "offset": float(index) * 5.0
        })

func _part(parent: Node3D, part_name: String, position_value: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    part.position = position_value
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    part.material_override = material
    parent.add_child(part)
    return part

func _process(delta: float) -> void:
    _elapsed += delta
    var length: float = district_extent * 1.65
    for data in _walkers:
        var root: Node3D = data["root"]
        var side: int = data["side"]
        var speed: float = data["speed"]
        var progress: float = fposmod(_elapsed * speed + data["offset"], length) - length * 0.5
        var sidewalk_center: float = 5.0
        match side:
            0:
                root.position = Vector3(sidewalk_center, 0.2, progress)
                root.rotation.y = PI
            1:
                root.position = Vector3(-sidewalk_center, 0.2, -progress)
                root.rotation.y = 0.0
            2:
                root.position = Vector3(progress, 0.2, sidewalk_center)
                root.rotation.y = -PI * 0.5
            3:
                root.position = Vector3(-progress, 0.2, -sidewalk_center)
                root.rotation.y = PI * 0.5
        var swing: float = sin(_elapsed * speed * 7.0 + data["phase"]) * 0.35
        var arms: Array = data["arms"]
        var legs: Array = data["legs"]
        arms[0].rotation.x = swing
        arms[1].rotation.x = -swing
        legs[0].rotation.x = -swing
        legs[1].rotation.x = swing
