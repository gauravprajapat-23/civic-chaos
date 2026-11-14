class_name CivicMobileJoystick
extends Node2D
## Original thumbstick, visually familiar to mobile action-game controls.
## Input event strength preserves analog walk speed; no backend or assets.
const AXES := ["move_left", "move_right", "move_forward", "move_back"]
@export var radius: float = 74.0
@export var deadzone: float = 0.14
var pointer_id: int = -1
var value: Vector2 = Vector2.ZERO
var enabled_on_desktop: bool = false

func _ready() -> void:
    set_process_input(true)
    visible = OS.has_feature("mobile") or enabled_on_desktop
    queue_redraw()

func configure(center: Vector2, new_radius: float) -> void:
    position = center
    radius = maxf(36.0, new_radius)
    queue_redraw()

static func normalized_offset(touch: Vector2, center: Vector2, max_radius: float, axis_deadzone: float = 0.14) -> Vector2:
    if max_radius <= 0.0:
        return Vector2.ZERO
    var stick: Vector2 = ((touch - center) / max_radius).limit_length(1.0)
    var amount: float = stick.length()
    if amount <= axis_deadzone:
        return Vector2.ZERO
    return stick.normalized() * ((amount - axis_deadzone) / (1.0 - axis_deadzone))

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and pointer_id == -1 and touch.position.distance_to(global_position) <= radius * 1.4:
            pointer_id = touch.index
            _set_stick(touch.position)
            get_viewport().set_input_as_handled()
        elif not touch.pressed and touch.index == pointer_id:
            release_stick()
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == pointer_id:
            _set_stick(drag.position)
            get_viewport().set_input_as_handled()

func _set_stick(point: Vector2) -> void:
    value = normalized_offset(point, global_position, radius, deadzone)
    _apply_actions()
    queue_redraw()

func release_stick() -> void:
    pointer_id = -1
    value = Vector2.ZERO
    _apply_actions()
    queue_redraw()

func _apply_actions() -> void:
    var amounts := [maxf(0.0, -value.x), maxf(0.0, value.x),
        maxf(0.0, -value.y), maxf(0.0, value.y)]
    for i in range(AXES.size()):
        var amount: float = amounts[i]
        if amount > 0.001:
            Input.action_press(AXES[i], amount)
        else:
            Input.action_release(AXES[i])

func _notification(what: int) -> void:
    # Android may not deliver touch-up after the app loses focus.
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        release_stick()

func _exit_tree() -> void:
    release_stick()

func _draw() -> void:
    if not visible:
        return
    draw_circle(Vector2.ZERO, radius, Color(0.06, 0.10, 0.16, 0.24), true, -1.0, true)
    draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 64, Color(0.84, 0.91, 1.0, 0.54), 3.0, true)
    draw_circle(value * (radius * 0.62), radius * 0.37, Color(0.18, 0.29, 0.42, 0.75), true, -1.0, true)
    draw_arc(value * (radius * 0.62), radius * 0.36, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.84), 2.0, true)
