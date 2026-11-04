extends Control
## Entry menu for the CC-005 lifecycle framework.

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _on_quit_pressed() -> void:
    get_tree().quit()
