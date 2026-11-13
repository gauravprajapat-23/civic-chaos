class_name CivicNeighborhoodService
extends StaticBody3D
## PROG-04: physical E/USE access point for earned neighborhood services.
## No physics obstruction outside this intentional small interaction target.
signal activated(actor: Node, project_index: int)

var project_index: int = -1
var caption: Label3D

func setup(index: int, text: String) -> void:
    project_index = index
    if caption != null:
        caption.text = text

func _ready() -> void:
    collision_layer = 0
    collision_mask = 0
    var shape := CollisionShape3D.new()
    shape.name = "InteractionShape"
    var box := BoxShape3D.new()
    box.size = Vector3(0.6, 1.2, 0.6)
    shape.shape = box
    shape.position.y = 0.6
    add_child(shape)
    caption = Label3D.new()
    caption.name = "Caption"
    caption.position = Vector3(0, 1.6, 0)
    caption.font_size = 28
    caption.pixel_size = 0.006
    add_child(caption)

func set_available(available: bool) -> void:
    visible = available
    collision_layer = 16 if available else 0

func interact(actor: Node) -> void:
    if visible and collision_layer == 16 and project_index >= 0:
        activated.emit(actor, project_index)
