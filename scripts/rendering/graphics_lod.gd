class_name CivicGraphicsLOD
extends Node
## Distance-based mesh visibility and mobile lighting budgets.
enum Quality { LOW, BALANCED, HIGH }
@export var quality: Quality = Quality.BALANCED
@export var near_distance: float = 28.0
@export var far_distance: float = 70.0
@export var update_interval: float = 0.25
var camera: Camera3D
var tracked: Array[Dictionary] = []
var _elapsed: float = 0.0

func configure(view_camera: Camera3D, selected_quality: Quality) -> bool:
    if view_camera == null or near_distance <= 0.0 or far_distance <= near_distance:
        return false
    camera = view_camera
    quality = selected_quality
    return true

func register_mesh(mesh: MeshInstance3D, low_detail: MeshInstance3D = null) -> bool:
    if mesh == null or not is_instance_valid(mesh):
        return false
    for entry in tracked:
        if entry["high"] == mesh:
            return false
    tracked.append({"high": mesh, "low": low_detail})
    return true

func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed < update_interval:
        return
    _elapsed = 0.0
    update_lod()

func update_lod() -> void:
    if camera == null or not is_instance_valid(camera):
        return
    var kept: Array[Dictionary] = []
    for entry in tracked:
        var high: MeshInstance3D = entry["high"]
        var low: MeshInstance3D = entry["low"]
        if not is_instance_valid(high):
            continue
        var distance := camera.global_position.distance_to(high.global_position)
        var cutoff := far_distance * (0.65 if quality == Quality.LOW else 1.5 if quality == Quality.HIGH else 1.0)
        var switch_distance := near_distance * (0.65 if quality == Quality.LOW else 1.5 if quality == Quality.HIGH else 1.0)
        if low != null and is_instance_valid(low):
            high.visible = distance <= switch_distance
            low.visible = distance > switch_distance and distance <= cutoff
        else:
            high.visible = distance <= cutoff
        kept.append(entry)
    tracked = kept

func apply_light_budget(root_node: Node) -> void:
    var lights: Array[Light3D] = []
    _collect_lights(root_node, lights)
    var allowed := 1 if quality == Quality.LOW else 2 if quality == Quality.BALANCED else 4
    for index in range(lights.size()):
        lights[index].shadow_enabled = index < allowed and quality != Quality.LOW

func _collect_lights(node: Node, result: Array[Light3D]) -> void:
    if node is Light3D:
        result.append(node)
    for child in node.get_children():
        _collect_lights(child, result)
