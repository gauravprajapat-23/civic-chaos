class_name CivicGameLifecycle
extends Node
## Owns scene changes, pause, restart, and save/load.

signal lifecycle_message(message: String)

const SaveRepo = preload("res://scripts/core/save_repository.gd")
const GAME_SCENE: String = "res://scenes/core/main.tscn"
const MENU_SCENE: String = "res://scenes/core/menu.tscn"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func start_game() -> void:
    _switch_scene(GAME_SCENE)

func return_to_menu() -> void:
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _switch_scene(MENU_SCENE)

func restart_game() -> void:
    get_tree().paused = false
    _switch_scene(GAME_SCENE)

func set_paused(value: bool) -> void:
    get_tree().paused = value
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func save_player(player: Node3D) -> bool:
    var pos := player.global_position
    var data := {"player": {"x": pos.x, "y": pos.y, "z": pos.z, "yaw": player.rotation.y}}
    var ok: bool = SaveRepo.write_save(data)
    lifecycle_message.emit("Game saved" if ok else "Save failed")
    return ok

func load_player(player: Node3D) -> bool:
    var data: Dictionary = SaveRepo.read_save()
    if data.is_empty():
        lifecycle_message.emit("No valid save found")
        return false
    var state: Dictionary = data["player"]
    player.global_position = Vector3(float(state["x"]), float(state["y"]), float(state["z"]))
    player.rotation.y = float(state["yaw"])
    if player is CharacterBody3D:
        (player as CharacterBody3D).velocity = Vector3.ZERO
    lifecycle_message.emit("Save loaded")
    return true

func _switch_scene(path: String) -> void:
    get_tree().paused = false
    var error := get_tree().change_scene_to_file(path)
    if error != OK:
        lifecycle_message.emit("Could not open scene: %s" % path)
