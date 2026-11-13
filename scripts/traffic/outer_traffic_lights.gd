class_name CivicOuterTrafficLights
extends Node3D
## AUD2-MAP-04: visual signal heads driven ONLY by the restored logical tick.
## A presentation node: no physics bodies, persisted data, or traffic authority.
const Grid = preload("res://scripts/world/city_road_layout.gd")
const Policy = preload("res://scripts/traffic/outer_intersection_priority.gd")

var _lamps: Array[Dictionary] = []
var displayed_tick: int = -1
var _red_material: StandardMaterial3D
var _green_material: StandardMaterial3D
var _dim_material: StandardMaterial3D

func _ready() -> void:
    _red_material = _material(Color(0.95, 0.10, 0.07))
    _green_material = _material(Color(0.07, 0.92, 0.25))
    _dim_material = _material(Color(0.16, 0.17, 0.18))
    _build()
    sync_tick(0)

static func _material(color: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return result

func _build() -> void:
    var coordinates: Array[float] = Grid.coordinates()
    for x in coordinates:
        for z in coordinates:
            if absf(x) < 0.01 and absf(z) < 0.01:
                continue
            var node := Vector3(x, 0.0, z)
            # Separate axis-specific heads at each outer city intersection.
            # Never add colliders to traffic signage: this fixes visibility
            # without blocking vehicles or pedestrians.
            _add_head(node + Vector3(3.5, 0.0, 3.5), "ns")
            _add_head(node + Vector3(-3.5, 0.0, -3.5), "ew")

func _add_head(at: Vector3, axis: String) -> void:
    var head := Node3D.new()
    head.name = "%s_%d" % [axis.to_upper(), _lamps.size()]
    head.position = at
    add_child(head)
    var pole := MeshInstance3D.new()
    pole.name = "Pole"
    pole.position = Vector3(0.0, 1.65, 0.0)
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.075
    cylinder.bottom_radius = 0.075
    cylinder.height = 3.3
    pole.mesh = cylinder
    head.add_child(pole)
    var housing := MeshInstance3D.new()
    housing.name = "SignalHousing"
    housing.position = Vector3(0.0, 3.2, 0.0)
    var housing_mesh := BoxMesh.new()
    housing_mesh.size = Vector3(0.6, 1.2, 0.4)
    housing.mesh = housing_mesh
    head.add_child(housing)
    var red := _bulb(head, "RedBulb", Vector3(0, 3.50, -0.24))
    var green := _bulb(head, "GreenBulb", Vector3(0, 2.94, -0.24))
    _lamps.append({"axis": axis, "red": red, "green": green})

func _bulb(head: Node3D, label: String, position: Vector3) -> MeshInstance3D:
    var light := MeshInstance3D.new()
    light.name = label
    light.position = position
    var mesh := SphereMesh.new()
    mesh.radius = 0.18
    mesh.height = 0.36
    light.mesh = mesh
    head.add_child(light)
    return light

func sync_tick(tick: int) -> void:
    displayed_tick = tick
    for head in _lamps:
        var green: bool = Policy.aspect(str(head["axis"]), tick) == "green"
        (head["green"] as MeshInstance3D).material_override = _green_material if green else _dim_material
        (head["red"] as MeshInstance3D).material_override = _dim_material if green else _red_material

func head_count() -> int:
    return _lamps.size()

func displayed_aspect(axis: String) -> String:
    return Policy.aspect(axis, displayed_tick)
