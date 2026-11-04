@tool
class_name CivicRoadSegment
extends Node3D
## Reusable visual segment between two world-space endpoints.

@export var start_point: Vector3 = Vector3(-10, 0, 0):
    set(value):
        start_point = value
        _refresh()
@export var end_point: Vector3 = Vector3(10, 0, 0):
    set(value):
        end_point = value
        _refresh()
@export_range(1.0, 20.0, 0.1) var road_width: float = 7.0:
    set(value):
        road_width = value
        _refresh()

func _ready() -> void:
    _refresh()

func _refresh() -> void:
    if not is_inside_tree():
        return
    var mesh_node := get_node_or_null("RoadMesh") as MeshInstance3D
    if mesh_node == null:
        return
    var distance := start_point.distance_to(end_point)
    if distance <= 0.001:
        mesh_node.visible = false
        return
    mesh_node.visible = true
    var box := BoxMesh.new()
    box.size = Vector3(road_width, 0.12, distance)
    mesh_node.mesh = box
    mesh_node.position = (start_point + end_point) * 0.5
    mesh_node.rotation.y = atan2(-(end_point - start_point).x, -(end_point - start_point).z)

func matches_endpoints(a: Vector3, b: Vector3, tolerance: float = 0.05) -> bool:
    return start_point.distance_to(a) <= tolerance and end_point.distance_to(b) <= tolerance
