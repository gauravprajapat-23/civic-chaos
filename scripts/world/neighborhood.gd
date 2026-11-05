@tool
class_name CivicNeighborhood
extends Node3D
## Reusable deterministic district around the existing four-way junction.
@export var district_extent: float = 38.0
@export var road_width: float = 8.0
@export var sidewalk_width: float = 2.0
@export var building_height: float = 8.0

func _ready() -> void:
    rebuild()

func rebuild() -> void:
    for child in get_children():
        child.free()
    if district_extent < 20.0 or road_width < 4.0 or sidewalk_width < 1.0:
        push_warning("Invalid neighborhood dimensions")
        return
    var half := district_extent
    var road_half := road_width * 0.5
    _block("NorthRoad", Vector3(0, -0.04, -half * 0.5), Vector3(road_width, 0.08, half))
    _block("SouthRoad", Vector3(0, -0.04, half * 0.5), Vector3(road_width, 0.08, half))
    _block("EastRoad", Vector3(half * 0.5, -0.04, 0), Vector3(half, 0.08, road_width))
    _block("WestRoad", Vector3(-half * 0.5, -0.04, 0), Vector3(half, 0.08, road_width))
    for side in [-1, 1]:
        var sign_value: float = float(side)
        _block("SidewalkX%d" % side, Vector3(sign_value * (road_half + sidewalk_width * 0.5), 0.1, 0), Vector3(sidewalk_width, 0.2, half * 2.0))
        _block("SidewalkZ%d" % side, Vector3(0, 0.1, sign_value * (road_half + sidewalk_width * 0.5)), Vector3(half * 2.0, 0.2, sidewalk_width))
    for x in [-1, 1]:
        for z in [-1, 1]:
            var center := Vector3(float(x) * (road_half + 9.0), building_height * 0.5, float(z) * (road_half + 9.0))
            _block("Building_%d_%d" % [x, z], center, Vector3(10, building_height, 10))
    _lane_markings(half, road_half)
    for arm in range(4):
        var marker := Node3D.new()
        marker.name = "Crossing_%d" % arm
        var offset := road_half + sidewalk_width + 2.0
        marker.position = [Vector3(0, 0.03, -offset), Vector3(offset, 0.03, 0), Vector3(0, 0.03, offset), Vector3(-offset, 0.03, 0)][arm]
        add_child(marker)
        var stripe := MeshInstance3D.new()
        stripe.mesh = BoxMesh.new()
        stripe.mesh.size = Vector3(road_width, 0.04, 1.2) if arm % 2 == 0 else Vector3(1.2, 0.04, road_width)
        stripe.material_override = _material(Color(0.96, 0.95, 0.86))
        marker.add_child(stripe)
    var info_scene := load("res://scenes/world/interaction_marker.tscn") as PackedScene
    if info_scene != null:
        var info := info_scene.instantiate() as Node3D
        info.name = "DistrictInfoPoint"
        info.position = Vector3(road_half + sidewalk_width + 1.0, 0.2, -12)
        add_child(info)

func _block(block_name: String, center: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = block_name
    body.position = center
    add_child(body)
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    var mesh := MeshInstance3D.new()
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    body.add_child(mesh)
    if block_name.ends_with("Road"):
        mesh.material_override = _material(Color(0.15, 0.18, 0.21))
    elif block_name.begins_with("Sidewalk"):
        mesh.material_override = _material(Color(0.64, 0.65, 0.61))
    elif block_name.begins_with("Building_"):
        var building_colors := [Color(0.83, 0.59, 0.42), Color(0.58, 0.69, 0.72), Color(0.78, 0.74, 0.61), Color(0.71, 0.64, 0.76)]
        var color_index: int = abs(int(center.x + center.z)) % building_colors.size()
        mesh.material_override = _material(building_colors[color_index])
    if block_name.begins_with("Building_"):
        mesh.add_to_group("lod_meshes")

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.92
    return material

func _lane_markings(half: float, road_half: float) -> void:
    var marking_material := _material(Color(0.97, 0.83, 0.28))
    for axis in range(2):
        for side in [-1, 1]:
            for step in range(1, int(half / 4.0)):
                var distance: float = float(step) * 4.0 + 2.0
                if distance > half - 2.0:
                    continue
                var marking := MeshInstance3D.new()
                marking.name = "LaneDash_%d_%d_%d" % [axis, side, step]
                var mesh := BoxMesh.new()
                mesh.size = Vector3(0.12, 0.025, 1.7) if axis == 0 else Vector3(1.7, 0.025, 0.12)
                marking.mesh = mesh
                marking.material_override = marking_material
                marking.position = Vector3(0, 0.025, float(side) * distance) if axis == 0 else Vector3(float(side) * distance, 0.025, 0)
                add_child(marking)
