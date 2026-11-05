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
            var variation: int = (x + 1) + (z + 1) * 2
            var height: float = building_height * [1.0, 1.25, 0.85, 1.5][variation]
            var width: float = [10.0, 9.0, 11.0, 9.5][variation]
            var center := Vector3(float(x) * (road_half + 9.0), height * 0.5, float(z) * (road_half + 9.0))
            _block("Building_%d_%d" % [x, z], center, Vector3(width, height, width))
    _lane_markings(half, road_half)
    _curb_accents(half, road_half)
    # Paint individual zebra stripes instead of a single white slab.
    var crossing_material := _material(Color(0.96, 0.96, 0.91))
    for arm in range(4):
        var crossing := Node3D.new()
        crossing.name = "Crossing_%d" % arm
        var offset: float = road_half + sidewalk_width + 2.0
        crossing.position = [
            Vector3(0, 0.055, -offset), Vector3(offset, 0.055, 0),
            Vector3(0, 0.055, offset), Vector3(-offset, 0.055, 0)
        ][arm]
        add_child(crossing)
        for stripe_index in range(7):
            var stripe := MeshInstance3D.new()
            stripe.name = "ZebraStripe_%d" % stripe_index
            var stripe_mesh := BoxMesh.new()
            var across: float = -3.2 + float(stripe_index) * 1.05
            if arm % 2 == 0:
                stripe_mesh.size = Vector3(0.62, 0.012, 1.8)
                stripe.position.x = across
            else:
                stripe_mesh.size = Vector3(1.8, 0.012, 0.62)
                stripe.position.z = across
            stripe.mesh = stripe_mesh
            stripe.material_override = crossing_material
            crossing.add_child(stripe)
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
        var color_index: int = (int(center.x > 0.0) + 2 * int(center.z > 0.0)) % building_colors.size()
        mesh.material_override = _material(building_colors[color_index])
    if block_name.begins_with("Building_"):
        mesh.add_to_group("lod_meshes")
        _decorate_building(body, size)

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

func _curb_accents(half: float, road_half: float) -> void:
    # Thin raised edges add street depth without extra physics or textures.
    var curb_material := _material(Color(0.81, 0.78, 0.69))
    for side in [-1, 1]:
        var direction: float = float(side)
        _facade_panel(self, "CurbNorthSouth_%d" % side,
            Vector3(direction * (road_half + 0.08), 0.13, 0),
            Vector3(0.16, 0.18, half * 2.0), curb_material)
        _facade_panel(self, "CurbEastWest_%d" % side,
            Vector3(0, 0.13, direction * (road_half + 0.08)),
            Vector3(half * 2.0, 0.18, 0.16), curb_material)

func _decorate_building(building: Node3D, size: Vector3) -> void:
    var glass := _material(Color(0.17, 0.31, 0.40))
    var frame := _material(Color(0.91, 0.88, 0.78))
    var roof := _material(Color(0.30, 0.32, 0.35))
    var trim := MeshInstance3D.new()
    trim.name = "RoofTrim"
    var trim_mesh := BoxMesh.new()
    trim_mesh.size = Vector3(size.x + 0.5, 0.3, size.z + 0.5)
    trim.mesh = trim_mesh
    trim.position.y = size.y * 0.5 + 0.15
    trim.material_override = roof
    building.add_child(trim)
    var floor_count: int = maxi(1, int(size.y / 2.5))
    for floor_index in range(floor_count):
        var y: float = -size.y * 0.5 + 1.7 + float(floor_index) * 2.5
        for column in range(3):
            var x: float = -3.0 + float(column) * 3.0
            _facade_panel(building, "WindowFront_%d_%d" % [floor_index, column], Vector3(x, y, -size.z * 0.5 - 0.025), Vector3(1.25, 1.35, 0.07), glass)
            _facade_panel(building, "WindowBack_%d_%d" % [floor_index, column], Vector3(x, y, size.z * 0.5 + 0.025), Vector3(1.25, 1.35, 0.07), glass)
            _facade_panel(building, "WindowSide_%d_%d" % [floor_index, column], Vector3(-size.x * 0.5 - 0.025, y, x), Vector3(0.07, 1.35, 1.25), glass)
    var awning := _material(Color(0.29, 0.43, 0.48))
    var sill := _material(Color(0.84, 0.81, 0.73))
    for floor_index in range(floor_count):
        var y: float = -size.y * 0.5 + 0.94 + float(floor_index) * 2.5
        if y + 0.2 < size.y * 0.5:
            for column in range(3):
                var x: float = -3.0 + float(column) * 3.0
                _facade_panel(building, "WindowSill_%d_%d" % [floor_index, column],
                    Vector3(x, y, -size.z * 0.5 - 0.11), Vector3(1.55, 0.12, 0.28), sill)
    _facade_panel(building, "EntranceAwning",
        Vector3(0, -size.y * 0.5 + 2.45, -size.z * 0.5 - 0.55),
        Vector3(2.6, 0.16, 1.2), awning)
    _facade_panel(building, "Entrance", Vector3(0, -size.y * 0.5 + 1.1, -size.z * 0.5 - 0.05), Vector3(1.7, 2.2, 0.10), roof)
    _facade_panel(building, "DoorHandle", Vector3(0.6, -size.y * 0.5 + 1.1, -size.z * 0.5 - 0.12), Vector3(0.08, 0.15, 0.05), frame)

func _facade_panel(parent: Node3D, panel_name: String, location: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> void:
    var panel := MeshInstance3D.new()
    panel.name = panel_name
    panel.position = location
    var panel_mesh := BoxMesh.new()
    panel_mesh.size = dimensions
    panel.mesh = panel_mesh
    panel.material_override = material
    parent.add_child(panel)
