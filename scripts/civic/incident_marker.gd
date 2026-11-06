class_name CivicIncidentMarker
extends StaticBody3D
## In-world reportable obstruction. Its collider really blocks the sidewalk.
signal activated(by_player: Node)
@export var incident_id: int = -1

func _ready() -> void:
    collision_layer = 1
    collision_mask = 0
    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    collision.position = Vector3(0, 0.55, 0)
    var box := BoxShape3D.new()
    box.size = Vector3(1.25, 1.10, 1.2)
    collision.shape = box
    add_child(collision)
    var mesh := MeshInstance3D.new()
    mesh.name = "ObstructionVisual"
    mesh.position = collision.position
    var cube := BoxMesh.new()
    cube.size = box.size
    mesh.mesh = cube
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.94, 0.45, 0.13)
    mesh.material_override = material
    add_child(mesh)
    var label := Label3D.new()
    label.text = "FOOTPATH BLOCKED"
    label.font_size = 48
    label.pixel_size = 0.005
    label.position = Vector3(0, 1.55, 0)
    add_child(label)

func interact(by_player: Node) -> void:
    activated.emit(by_player)
