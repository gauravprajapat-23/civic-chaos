class_name CivicTrafficMarshalPanel
extends CanvasLayer
## TRAFFIC-GAME-02: compact, keyboard/mobile-accessible action sheet.
## Visuals never control signals directly; requests go through Main.
signal axis_requested(axis: String)
signal metering_requested
signal closed

var frame: PanelContainer
var heading: Label
var status: Label
var ns_button: Button
var ew_button: Button
var south_button: Button
var west_button: Button
var meter_button: Button
var close_button: Button
var _opened: bool = false

func _ready() -> void:
    layer = 35
    visible = false
    var margin := MarginContainer.new()
    margin.name = "MarshalPosition"
    margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(margin)
    frame = PanelContainer.new()
    frame.name = "MarshalPanel"
    frame.custom_minimum_size = Vector2(320, 0)
    margin.add_child(frame)
    var content := VBoxContainer.new()
    content.name = "ActionContent"
    content.add_theme_constant_override("separation", 8)
    frame.add_child(content)
    heading = Label.new()
    heading.name = "Title"
    heading.text = "TRAFFIC MARSHAL | INTERSECTION"
    heading.add_theme_font_size_override("font_size", 18)
    content.add_child(heading)
    status = Label.new()
    status.name = "SignalStatus"
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.text = "Read signals and wait for a safe opening."
    content.add_child(status)
    ns_button = _make_button(content, "Next: NORTH green", "N")
    ew_button = _make_button(content, "Next: EAST green", "E")
    south_button = _make_button(content, "Next: SOUTH green", "S")
    west_button = _make_button(content, "Next: WEST green", "W")
    meter_button = _make_button(content, "Meter new arrivals (20 s)", "Meter")
    close_button = _make_button(content, "Close", "Close")
    ns_button.pressed.connect(func() -> void: axis_requested.emit("N"))
    ew_button.pressed.connect(func() -> void: axis_requested.emit("E"))
    south_button.pressed.connect(func() -> void: axis_requested.emit("S"))
    west_button.pressed.connect(func() -> void: axis_requested.emit("W"))
    meter_button.pressed.connect(func() -> void: metering_requested.emit())
    close_button.pressed.connect(close_panel)
    get_viewport().size_changed.connect(_fit)
    _fit()

func _make_button(parent: VBoxContainer, label: String, key: String) -> Button:
    var result := Button.new()
    result.name = key
    result.text = label
    result.custom_minimum_size = Vector2(270, 44)
    result.focus_mode = Control.FOCUS_ALL
    parent.add_child(result)
    return result

func _fit() -> void:
    var margin: MarginContainer = get_node_or_null("MarshalPosition") as MarginContainer
    if margin == null:
        return
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    var available_width: float = minf(370.0, maxf(280.0, viewport.x - 28.0))
    margin.offset_left = -available_width * 0.5
    margin.offset_right = available_width * 0.5
    margin.offset_top = -190.0
    margin.offset_bottom = 190.0
    if frame != null:
        frame.custom_minimum_size.x = available_width

func show_panel(message: String) -> void:
    if not is_node_ready():
        return
    status.text = message
    _opened = true
    visible = true
    ns_button.grab_focus()

func set_status(message: String) -> void:
    if status != null:
        status.text = message

func close_panel() -> void:
    if not _opened:
        return
    _opened = false
    visible = false
    closed.emit()

func is_open() -> bool:
    return _opened
