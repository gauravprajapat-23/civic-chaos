class_name CivicTouchControls
extends CanvasLayer
## On-screen action buttons with safe-area-aware viewport-relative placement.
var buttons: Dictionary = {}
var labels: Dictionary = {}
var actions := ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "interact", "pause_game"]
var captions := ["UP", "DOWN", "LEFT", "RIGHT", "JUMP", "RUN", "USE", "PAUSE"]
var positions := [Vector2(0.13, 0.72), Vector2(0.13, 0.89), Vector2(0.05, 0.81), Vector2(0.21, 0.81), Vector2(0.88, 0.84), Vector2(0.77, 0.84), Vector2(0.88, 0.69), Vector2(0.94, 0.09)]
var button_size := Vector2(72, 64)

func _ready() -> void:
    layer = 15
    for index in range(actions.size()):
        var button := TouchScreenButton.new()
        button.name = actions[index]
        button.action = actions[index]
        button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
        var shape := RectangleShape2D.new()
        shape.size = button_size
        button.shape = shape
        button.shape_centered = false
        add_child(button)
        buttons[actions[index]] = button
        var caption := Label.new()
        caption.name = actions[index] + "_caption"
        caption.text = captions[index]
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caption.custom_minimum_size = button_size
        add_child(caption)
        labels[actions[index]] = caption
    get_viewport().size_changed.connect(_layout)
    _layout()

func _layout() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var safe := DisplayServer.get_display_safe_area()
    var inset := Vector2.ZERO
    var usable := viewport_size
    if OS.has_feature("mobile") and safe.size.x > 0 and safe.size.y > 0:
        var scale_factor := viewport_size.x / maxf(float(DisplayServer.screen_get_size().x), 1.0)
        inset = Vector2(safe.position) * scale_factor
        usable = Vector2(safe.size) * scale_factor
    for index in range(actions.size()):
        var location: Vector2 = inset + usable * (positions[index] as Vector2) - button_size * 0.5
        location.x = clampf(location.x, 0.0, maxf(0.0, viewport_size.x - button_size.x))
        location.y = clampf(location.y, 0.0, maxf(0.0, viewport_size.y - button_size.y))
        (buttons[actions[index]] as TouchScreenButton).position = location
        (labels[actions[index]] as Label).position = location
        (labels[actions[index]] as Label).visible = OS.has_feature("mobile")
