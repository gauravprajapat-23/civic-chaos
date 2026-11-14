class_name CivicTouchControls
extends CanvasLayer
## MOB-CTRL-01: analog left stick; readable action buttons on the right.
## Camera look remains in the unoccupied right half of the viewport.
const Layout = preload("res://scripts/ui/touch_layout.gd")
const Joystick = preload("res://scripts/ui/mobile_joystick.gd")
const ACTIONS := ["jump", "sprint", "interact", "pause_game"]
const CAPTIONS := ["JUMP", "RUN", "USE", "II"]
var buttons: Dictionary = {}
var labels: Dictionary = {}
var actions := ["jump", "sprint", "interact", "pause_game"]
var joystick: CivicMobileJoystick
var _rects: Dictionary = {}
var _layout_valid: bool = false
signal pause_requested
signal interact_requested

## Release touch-owned movement and action state before modals, pause or
## focus loss. Do not leave a held on-screen button driving a hidden player.
func cancel_active_touches() -> void:
    if joystick != null:
        joystick.release_stick()
    for action in ACTIONS:
        if InputMap.has_action(action):
            Input.action_release(action)

func set_controls_active(active: bool) -> void:
    if not active:
        cancel_active_touches()
    visible = active

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        cancel_active_touches()


func _ready() -> void:
    layer = 15
    add_to_group("civic_touch_controls")
    joystick = Joystick.new() as CivicMobileJoystick
    joystick.name = "MovementJoystick"
    add_child(joystick)
    # Touch controls can be instantiated by a scene before gameplay's
    # keyboard mapping setup. Do not overwrite any existing bindings.
    for action in ACTIONS:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    # One texture shared across buttons, rather than four per-button image builds.
    var action_texture: Texture2D = _button_texture()
    for i in range(ACTIONS.size()):
        var action: String = ACTIONS[i]
        var button := TouchScreenButton.new()
        button.name = action
        button.action = action
        if action == "pause_game":
            button.pressed.connect(_on_pause_pressed)
        elif action == "interact":
            button.pressed.connect(_on_interact_pressed)
        button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
        button.shape_centered = true
        button.texture_normal = action_texture
        var shape := CircleShape2D.new()
        shape.radius = 28.0
        button.shape = shape
        add_child(button)
        buttons[action] = button
        var caption := Label.new()
        caption.name = action + "_caption"
        caption.text = CAPTIONS[i]
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        caption.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
        caption.add_theme_font_size_override("font_size", 15)
        add_child(caption)
        labels[action] = caption
    get_viewport().size_changed.connect(_layout)
    _layout()

func _button_texture() -> Texture2D:
    var image := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
    var center := Vector2(47.5, 47.5)
    for y in range(96):
        for x in range(96):
            var distance: float = Vector2(x, y).distance_to(center)
            var color := Color.TRANSPARENT
            if distance < 46.0:
                color = Color(0.10, 0.17, 0.26, 0.75)
            if distance >= 42.0 and distance < 46.0:
                color = Color(0.80, 0.89, 1.0, 0.85)
            image.set_pixel(x, y, color)
    return ImageTexture.create_from_image(image)

func _layout() -> void:
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    var safe := Rect2()
    if OS.has_feature("mobile"):
        var display: Rect2i = DisplayServer.get_display_safe_area()
        var actual: Vector2i = DisplayServer.screen_get_size()
        if display.size.x > 0 and display.size.y > 0 and actual.x > 0 and actual.y > 0:
            var ratio := Vector2(viewport.x / float(actual.x), viewport.y / float(actual.y))
            safe = Rect2(Vector2(display.position) * ratio, Vector2(display.size) * ratio)
    _apply_plan(Layout.joystick_plan(viewport, safe), OS.has_feature("mobile"))

## Apply the same geometry on desktop fixtures and Android. An invalid layout
## always clears stale hitboxes; recovering one restores every visible target.
func _apply_plan(plan: Dictionary, touch_device: bool) -> void:
    var valid: bool = bool(plan.get("ok", false))
    var rects: Dictionary = plan.get("rects", {}) if valid else {}
    # A finger captured against previous coordinates must not keep moving
    # the player after rotation, window resizing or a temporary bad layout.
    if not valid or not _layout_valid or rects != _rects:
        cancel_active_touches()
    _layout_valid = valid
    _rects = rects.duplicate()
    if not valid:
        joystick.visible = false
        for key in ACTIONS:
            (buttons[key] as TouchScreenButton).visible = false
            (labels[key] as Label).visible = false
        return

    joystick.configure(plan["joystick_center"], float(plan["joystick_radius"]))
    joystick.visible = touch_device
    if not touch_device:
        joystick.release_stick()
    for action in ACTIONS:
        var rect: Rect2 = rects[action]
        var button := buttons[action] as TouchScreenButton
        var label := labels[action] as Label
        var circle := button.shape as CircleShape2D
        # Collision radius is in texture-local coordinates; scaling both the
        # texture and circle keeps the visual and interactive sizes together.
        circle.radius = 48.0
        button.position = rect.position
        button.scale = Vector2.ONE * (rect.size.x / 96.0)
        label.position = rect.position
        label.size = rect.size
        button.visible = touch_device
        label.visible = touch_device

## Player uses this before claiming a look finger. Buttons should not
## accidentally turn the camera while tapping Jump, Run, Use or Pause.
func look_touch_allowed(point: Vector2) -> bool:
    if not visible or not _layout_valid:
        return true
    for rect_value in _rects.values():
        var rect: Rect2 = rect_value
        if rect.grow(8.0).has_point(point):
            return false
    return true

func _on_pause_pressed() -> void:
    pause_requested.emit()

func _on_interact_pressed() -> void:
    interact_requested.emit()

func _exit_tree() -> void:
    cancel_active_touches()
