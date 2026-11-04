extends Node3D
## Walking prototype entry point; input actions installed before player _ready.

@onready var status_label: Label = $CanvasLayer/HUD/VBoxContainer/Status
@onready var player: CivicPlayerController = $PlayerRoot

func _enter_tree() -> void:
    _bind_key("move_forward", KEY_W)
    _bind_key("move_back", KEY_S)
    _bind_key("move_left", KEY_A)
    _bind_key("move_right", KEY_D)
    _bind_key("sprint", KEY_SHIFT)
    _bind_key("jump", KEY_SPACE)
    _bind_key("interact", KEY_E)
    for action in ["look_left", "look_right", "look_up", "look_down"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)

func _bind_key(action: StringName, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var event := InputEventKey.new()
    event.physical_keycode = keycode
    if not InputMap.action_has_event(action, event):
        InputMap.action_add_event(action, event)

func _ready() -> void:
    player.interaction_message.connect(_on_interaction_message)
    status_label.text = "Explore and approach the civic information point"
    print("CIVIC_CHAOS_MAIN_READY")

func _on_interaction_message(message: String) -> void:
    status_label.text = message
