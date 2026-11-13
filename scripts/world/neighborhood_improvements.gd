class_name CivicNeighborhoodImprovements
extends Node3D
## PROG-03: persistent-looking city improvements reconstructed solely from
## audited Free Roam receipts. Visual only: no colliders, scores, or save fields.
const Progression = preload("res://scripts/civic/volunteer_progression.gd")
const MILESTONES: Array[int] = [3, 10, 25]
const PROJECT_NAMES: Array[String] = [
    "Market planters restored",
    "Community information kiosk renewed",
    "Neighborhood solar lighting installed"
]
const POSITIONS: Array[Vector3] = [
    Vector3(13.0, 0.0, -33.0),
    Vector3(33.0, 0.0, 13.0),
    Vector3(-33.0, 0.0, 13.0)
]

var _projects: Array[Node3D] = []
var _verified_count: int = 0

func _ready() -> void:
    for index in range(MILESTONES.size()):
        var project := Node3D.new()
        project.name = "Improvement_%d" % index
        project.position = POSITIONS[index]
        add_child(project)
        _assemble_project(project, index)
        project.visible = false
        _projects.append(project)

func _piece(parent: Node3D, name: String, position: Vector3,
        size: Vector3, color: Color) -> void:
    var item := MeshInstance3D.new()
    item.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    item.mesh = mesh
    item.position = position
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var paint := StandardMaterial3D.new()
    paint.albedo_color = color
    item.material_override = paint
    parent.add_child(item)

func _assemble_project(project: Node3D, index: int) -> void:
    match index:
        0:
            # A restored public planting area, outside the active road lanes.
            _piece(project, "Planter", Vector3(0, 0.45, 0),
                Vector3(2.2, 0.8, 0.8), Color(0.52, 0.32, 0.19))
            _piece(project, "Greenery", Vector3(0, 1.05, 0),
                Vector3(1.95, 0.45, 0.55), Color(0.12, 0.65, 0.25))
        1:
            # Public information display; no interactive button or collision.
            _piece(project, "KioskPost", Vector3(0, 1.05, 0),
                Vector3(0.26, 2.1, 0.25), Color(0.22, 0.34, 0.48))
            _piece(project, "CommunityBoard", Vector3(0, 2.0, 0),
                Vector3(2.2, 1.2, 0.19), Color(0.08, 0.49, 0.65))
        2:
            # Solar-lit street feature. It has no physics or point awards.
            _piece(project, "LampPole", Vector3(0, 1.7, 0),
                Vector3(0.24, 3.4, 0.24), Color(0.37, 0.43, 0.50))
            _piece(project, "SolarPanel", Vector3(0.0, 3.5, 0),
                Vector3(1.55, 0.14, 0.8), Color(0.07, 0.22, 0.40))
            _piece(project, "Lamp", Vector3(0.0, 3.2, -0.48),
                Vector3(0.8, 0.25, 0.5), Color(0.98, 0.91, 0.46))

func update_from_receipts(reputation: int, resolved: int, receipts: Dictionary) -> bool:
    if _projects.size() != MILESTONES.size():
        return false
    var overview: Dictionary = Progression.overview(reputation, resolved, receipts)
    if overview.is_empty():
        return false
    _verified_count = resolved
    for index in range(MILESTONES.size()):
        _projects[index].visible = resolved >= MILESTONES[index]
    return true

func project_state() -> Dictionary:
    var unlocked: Array[String] = []
    var next_name: String = ""
    var remaining: int = 0
    for index in range(MILESTONES.size()):
        if _projects[index].visible:
            unlocked.append(PROJECT_NAMES[index])
        elif next_name.is_empty():
            next_name = PROJECT_NAMES[index]
            remaining = MILESTONES[index] - _verified_count
    return {"unlocked": unlocked, "next_name": next_name, "remaining": remaining}

func project_visible(index: int) -> bool:
    return index >= 0 and index < _projects.size() and _projects[index].visible
