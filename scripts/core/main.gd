extends Node3D
## Walking prototype entry point.

@onready var status_label: Label = $CanvasLayer/HUD/VBoxContainer/Status
@onready var player: CivicPlayerController = $PlayerRoot

func _ready() -> void:
    player.interaction_message.connect(_on_interaction_message)
    status_label.text = "Explore and approach the civic information point"
    print("CIVIC_CHAOS_MAIN_READY")

func _on_interaction_message(message: String) -> void:
    status_label.text = message
