class_name CivicInteractionTarget
extends StaticBody3D

signal activated(by_player: Node)

@export var prompt_text: String = "Civic information point"

func interact(by_player: Node) -> void:
    activated.emit(by_player)
    if by_player.has_signal("interaction_message"):
        by_player.emit_signal("interaction_message", prompt_text)
