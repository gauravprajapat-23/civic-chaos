class_name CivicCleanupTarget
extends StaticBody3D
## GAME-021 interactive litter, two-slot bin, and municipal helper.
## Interaction layer 16 is picked by the existing player E/USE ray.
signal activated(actor: Node, kind: String, slot: int)

var kind: String = "litter"
var slot: int = -1
var description: String = ""
var caption: Label3D

func configure(target_kind: String, target_slot: int, display_name: String) -> void:
    kind = target_kind
    slot = target_slot
    description = display_name
    if caption != null:
        caption.text = display_name

func _ready() -> void:
    collision_layer = 16
    collision_mask = 0
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var body := BoxShape3D.new()
    var size := Vector3(0.46, 0.22, 0.46)
    var paint := Color(0.93, 0.62, 0.13)
    if kind == "bin":
        size = Vector3(1.05, 1.30, 1.05)
        paint = Color(0.16, 0.56, 0.28)
    elif kind == "helper":
        size = Vector3(0.60, 1.75, 0.60)
        paint = Color(0.14, 0.51, 0.66)
    body.size = size
    shape.shape = body
    shape.position.y = size.y * 0.5
    add_child(shape)
    var mesh := MeshInstance3D.new()
    mesh.name = "Visual"
    var cube := BoxMesh.new()
    cube.size = size
    mesh.mesh = cube
    mesh.position = shape.position
    var material := StandardMaterial3D.new()
    material.albedo_color = paint
    mesh.material_override = material
    add_child(mesh)
    caption = Label3D.new()
    caption.name = "Caption"
    caption.text = description
    caption.position = Vector3(0, maxf(0.75, size.y + 0.50), 0)
    caption.font_size = 36
    caption.pixel_size = 0.006
    add_child(caption)

func interact(actor: Node) -> void:
    if collision_layer == 16 and visible:
        activated.emit(actor, kind, slot)
