class_name CivicParkingOwner
extends StaticBody3D
## Friendly, non-blocking owner interaction point for GAME-016.
signal activated(actor: Node)
const CharacterArt = preload("res://scripts/rendering/low_poly_character.gd")

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

    CharacterArt.build(self, Color(0.22, 0.54, 0.66), Color(0.68, 0.44, 0.30),
        Color(0.19, 0.24, 0.31), Color(0.94, 0.75, 0.31))

    var caption := Label3D.new()
    caption.name = "OwnerCaption"
    caption.text = "VEHICLE OWNER\nE / USE TO TALK"
    caption.position = Vector3(0, 2.55, 0)
    caption.font_size = 42
    caption.pixel_size = 0.006
    add_child(caption)

func interact(actor: Node) -> void:
    activated.emit(actor)
