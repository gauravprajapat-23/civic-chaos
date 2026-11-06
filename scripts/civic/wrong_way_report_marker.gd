class_name CivicWrongWayReportMarker
extends StaticBody3D
## A visible, non-solid-to-player sidewalk report point, not a traffic blocker.
signal activated(actor: Node)

func _ready() -> void:
    collision_layer = 16 # Interactable sensor; player collides with world bit 1 only.
    collision_mask = 0
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    shape.position.y = 0.85
    var box := BoxShape3D.new()
    box.size = Vector3(1.3, 1.7, 0.6)
    shape.shape = box
    add_child(shape)
    var pole := MeshInstance3D.new()
    pole.name = "ReportPost"
    pole.position.y = 0.95
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.16, 1.9, 0.16)
    pole.mesh = mesh
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.96, 0.8, 0.19)
    pole.material_override = paint
    add_child(pole)
    var sign := Label3D.new()
    sign.name = "WrongWaySign"
    sign.text = "WRONG WAY!\nE / USE TO REPORT"
    sign.position = Vector3(0, 2.05, 0)
    sign.font_size = 50
    sign.pixel_size = 0.006
    add_child(sign)

func interact(actor: Node) -> void:
    activated.emit(actor)
