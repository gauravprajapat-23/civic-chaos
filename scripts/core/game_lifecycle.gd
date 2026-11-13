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

func save_player(player: Node3D, path: String = "", extra: Dictionary = {}) -> bool:
    var pos := player.global_position
    var data: Dictionary = {"player": {"x": pos.x, "y": pos.y, "z": pos.z, "yaw": player.rotation.y}}
    for key in extra.keys():
        if ["player", "version", "checksum"].has(key):
            lifecycle_message.emit("Save failed: invalid extra field")
            return false
        data[key] = extra[key]
    var destination: String = SaveRepo.DEFAULT_PATH if path.is_empty() else path
    var ok: bool = SaveRepo.write_save(data, destination)
    lifecycle_message.emit("Game saved" if ok else "Save failed")
    return ok

func load_player(player: Node3D, path: String = "") -> bool:
    var destination: String = SaveRepo.DEFAULT_PATH if path.is_empty() else path
    return load_player_snapshot(player, SaveRepo.read_save(destination))

## GAME-018: apply the very document already validated by the mission loader.
## Do not re-read the file between civic restore and player restore: a new F5
## or a primary->backup recovery could otherwise mix two save generations.
## GAME-020: pure eligibility preflight. The main scene runs this before
## any civic/world restore so a missing player or invalid position cannot
## reject a transaction after it has replaced background traffic.
func can_load_player_snapshot(player: Node3D, data: Dictionary) -> bool:
    return is_instance_valid(player) and player is CivicPlayerController and player.is_inside_tree() and SaveRepo._valid_player(data)

func load_player_snapshot(player: Node3D, data: Dictionary) -> bool:
    if data.is_empty() or not SaveRepo._valid_player(data):
        lifecycle_message.emit("No valid save found")
        return false
    if not player is CivicPlayerController:
        lifecycle_message.emit("Player cannot validate save position")
        return false
    var state: Dictionary = data["player"]
    var requested := Vector3(float(state["x"]), float(state["y"]), float(state["z"]))
    # Do not move an active physics body from an input event. The controller
    # checks floor normals, actor overlap and world clearance next physics tick.
    var accepted: bool = (player as CivicPlayerController).request_safe_restore(
        requested, float(state["yaw"])
    )
    lifecycle_message.emit("Checking saved position" if accepted else "Invalid saved position")
    return accepted

## The full civic/world restore already runs on a physics tick. Unlike
## load_player_snapshot(), this method reports ACTUAL safe placement before
## the checkpoint transaction is allowed to commit.
func restore_player_snapshot_now(player: Node3D, data: Dictionary) -> bool:
    if not can_load_player_snapshot(player, data):
        lifecycle_message.emit("Invalid saved player")
        return false
    var state: Dictionary = data["player"]
    var target := Vector3(float(state["x"]), float(state["y"]), float(state["z"]))
    var accepted: bool = (player as CivicPlayerController).restore_now_safe(
        target, float(state["yaw"])
    )
    lifecycle_message.emit("Save loaded" if accepted else "Saved position unsafe; checkpoint not applied")
    return accepted

func _switch_scene(path: String) -> void:
    get_tree().paused = false
    var error := get_tree().change_scene_to_file(path)
    if error != OK:
        lifecycle_message.emit("Could not open scene: %s" % path)
