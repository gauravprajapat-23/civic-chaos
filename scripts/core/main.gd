extends Node3D
## Minimal playable scene entry point. Gameplay systems are added in later issues.

@onready var status_label: Label = $CanvasLayer/CenterContainer/PanelContainer/VBoxContainer/Status

func _ready() -> void:
    status_label.text = "Civic Chaos foundation loaded"
    print("CIVIC_CHAOS_MAIN_READY")
