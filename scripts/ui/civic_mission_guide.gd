class_name CivicMissionGuide
extends CanvasLayer
## GAME-015: non-authoritative navigation, dialogue and deliberate recovery UI.
## Every position and progress statement comes from existing mission actors.
signal recovery_action_requested(action: String)

var mission_label: Label
var objective_label: Label
var waypoint_label: Label
var dialogue_label: Label
var help_label: Label
var reload_button: Button
var restart_button: Button
var confirmation: ConfirmationDialog
var _state: Dictionary = {}

func _ready() -> void:
    layer = 12 # Under the incident card, above the world/HUD.
    var frame := MarginContainer.new()
    frame.name = "GuideFrame"
    frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    frame.offset_left = -370.0
    frame.offset_right = -14.0
    frame.offset_top = 12.0
    frame.offset_bottom = 238.0
    frame.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(frame)
    var panel := PanelContainer.new()
    panel.name = "GuidePanel"
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    frame.add_child(panel)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 6)
    panel.add_child(stack)
    mission_label = _line(stack, "MissionTitle", 18)
    objective_label = _line(stack, "NextObjective", 16)
    waypoint_label = _line(stack, "Waypoint", 15)
    dialogue_label = _line(stack, "Dialogue", 14)
    help_label = _line(stack, "RecoveryHint", 14)
    var actions := HBoxContainer.new()
    actions.name = "RecoveryActions"
    stack.add_child(actions)
    reload_button = _button(actions, "Reload checkpoint", "ReloadCheckpoint")
    restart_button = _button(actions, "Restart level", "RestartLevel")
    reload_button.pressed.connect(func() -> void: recovery_action_requested.emit("reload_checkpoint"))
    restart_button.pressed.connect(_confirm_restart)
    confirmation = ConfirmationDialog.new()
    confirmation.title = "Restart Civic Chaos?"
    confirmation.dialog_text = "Restart the whole level? Unsaved mission progress will be lost."
    add_child(confirmation)
    confirmation.confirmed.connect(func() -> void: recovery_action_requested.emit("restart_level"))
    update_guide({"title": "Market Chowk", "objective": "Find the blocked footpath.",
        "has_target": false}, Vector3.ZERO, Vector3.FORWARD)

func _line(parent: VBoxContainer, node_name: String, size: int) -> Label:
    var label := Label.new()
    label.name = node_name
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _button(parent: HBoxContainer, title: String, node_name: String) -> Button:
    var button := Button.new()
    button.name = node_name
    button.text = title
    button.custom_minimum_size = Vector2(140, 48)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(button)
    return button

static func direction_prompt(origin: Vector3, forward: Vector3, target: Vector3) -> String:
    var delta := Vector2(target.x - origin.x, target.z - origin.z)
    var metres: float = delta.length()
    if metres < 2.0:
        return "HERE - within reach"
    var face := Vector2(forward.x, forward.z)
    if face.length_squared() < 0.0001:
        return "%dm away" % int(round(metres))
    face = face.normalized()
    var direction: Vector2 = delta / metres
    var dot: float = face.dot(direction)
    var side: float = face.x * direction.y - face.y * direction.x
    var turn: String = "AHEAD"
    if dot < -0.60:
        turn = "BEHIND"
    elif dot < 0.60:
        turn = "RIGHT" if side > 0.0 else "LEFT"
    return "%s  %dm" % [turn, int(round(metres))]

func update_guide(state: Dictionary, actor_position: Vector3, forward: Vector3) -> void:
    _state = state.duplicate(true)
    if mission_label == null:
        return
    mission_label.text = "MISSION | %s" % str(state.get("title", "Market Chowk"))
    objective_label.text = "NEXT | %s" % str(state.get("objective", "Explore the district."))
    var location: Variant = state.get("target", null)
    if bool(state.get("has_target", false)) and location is Vector3:
        waypoint_label.text = "WAYPOINT | %s" % direction_prompt(actor_position, forward, location)
    else:
        waypoint_label.text = "WAYPOINT | Follow the current objective"
    var speaker: String = str(state.get("speaker", "Neighborhood Radio"))
    dialogue_label.text = "%s | %s" % [speaker, str(state.get("dialogue", "Look for a civic issue."))]
    var can_recover: bool = bool(state.get("recovery_available", false))
    reload_button.visible = can_recover
    restart_button.visible = can_recover
    help_label.visible = can_recover
    help_label.text = str(state.get("recovery_reason", ""))
    reload_button.disabled = not can_recover
    restart_button.disabled = not can_recover

func request_reload() -> void:
    if reload_button != null and reload_button.visible and not reload_button.disabled:
        recovery_action_requested.emit("reload_checkpoint")

func _confirm_restart() -> void:
    if restart_button != null and restart_button.visible and not restart_button.disabled:
        confirmation.popup_centered()

func current_state() -> Dictionary:
    return _state.duplicate(true)
