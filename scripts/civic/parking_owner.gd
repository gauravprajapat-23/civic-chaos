class_name CivicParkingOwner
extends StaticBody3D
## Friendly, non-blocking owner interaction point for GAME-016.
signal activated(actor: Node)

func _ready() -> void:
    collision_layer = 16
    collision_mask = 0
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    shape.position = Vector3(0, 0.9, 0)
    var body := CapsuleShape3D.new()
    body.radius = 0.38
    body.height = 1.8
    shape.shape = body
    add_child(shape)

    var jacket := MeshInstance3D.new()
    jacket.name = "Jacket"
    jacket.position = Vector3(0, 1.1, 0)
    var jacket_mesh := CapsuleMesh.new()
    jacket_mesh.radius = 0.33
    jacket_mesh.height = 1.1
    jacket.mesh = jacket_mesh
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.22, 0.54, 0.66)
    jacket.material_override = paint
    add_child(jacket)

    var head := MeshInstance3D.new()
    head.name = "Head"
    head.position = Vector3(0, 1.82, 0)
    var sphere := SphereMesh.new()
    sphere.radius = 0.24
    sphere.height = 0.48
    head.mesh = sphere
    add_child(head)

    var caption := Label3D.new()
    caption.name = "OwnerCaption"
    caption.text = "VEHICLE OWNER\nE / USE TO TALK"
    caption.position = Vector3(0, 2.55, 0)
    caption.font_size = 42
    caption.pixel_size = 0.006
    add_child(caption)

func interact(actor: Node) -> void:
    activated.emit(actor)
