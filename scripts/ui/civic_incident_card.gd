class_name CivicIncidentDetailCard
extends CanvasLayer
## GAME-008: one modal, responsive evidence/action surface for PC and mobile.
## It owns no gameplay state: every choice goes through CivicGameplaySession.
signal action_selected(action: String)
signal dismissed

var backdrop: ColorRect
var panel: PanelContainer
var title_label: Label
var location_label: Label
var evidence_label: Label
var phase_label: Label
var hint_label: Label
var inspect_button: Button
var report_button: Button
var close_button: Button
var _state: Dictionary = {}

func _ready() -> void:
    layer = 25 # Above the HUD and virtual controls.
    backdrop = ColorRect.new()
    backdrop.name = "ModalBackdrop"
    backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(backdrop)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    center.name = "Center"
    center.mouse_filter = Control.MOUSE_FILTER_PASS
    backdrop.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel = PanelContainer.new()
    panel.name = "IncidentPanel"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    center.add_child(panel)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 9)
    panel.add_child(layout)
    title_label = _line(layout, "Title", 21)
    location_label = _line(layout, "Location", 15)
    evidence_label = _line(layout, "Evidence", 16)
    phase_label = _line(layout, "Phase", 16)
    hint_label = _line(layout, "Hint", 14)
    inspect_button = _action(layout, "Inspect Evidence", "InspectButton")
    report_button = _action(layout, "Report to Municipal Service", "ReportButton")
    close_button = _action(layout, "Close / Return to City", "CloseButton")
    inspect_button.pressed.connect(_on_inspect)
    report_button.pressed.connect(_on_report)
    close_button.pressed.connect(dismiss)
    get_viewport().size_changed.connect(_fit)
    _fit()
    backdrop.visible = false

func _line(container: VBoxContainer, node_name: String, font_size: int) -> Label:
    var label := Label.new()
    label.name = node_name
    label.add_theme_font_size_override("font_size", font_size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    container.add_child(label)
    return label

func _action(container: VBoxContainer, caption: String, node_name: String) -> Button:
    var button := Button.new()
    button.name = node_name
    button.text = caption
    button.custom_minimum_size = Vector2(0.0, 52.0)
    button.focus_mode = Control.FOCUS_ALL
    container.add_child(button)
    return button

func _fit() -> void:
    if panel == null:
        return
    var screen: Vector2 = get_viewport().get_visible_rect().size
    panel.custom_minimum_size = Vector2(minf(470.0, maxf(180.0, screen.x - 32.0)), 0.0)

func present(data: Dictionary) -> void:
    if backdrop == null:
        return
    backdrop.visible = true
    render_card(data)
    if not inspect_button.disabled:
        inspect_button.grab_focus()
    elif not report_button.disabled:
        report_button.grab_focus()
    else:
        close_button.grab_focus()

func render_card(data: Dictionary) -> void:
    _state = data.duplicate(true)
    if title_label == null:
        return
    title_label.text = str(data.get("title", "Civic incident"))
    location_label.text = "LOCATION | %s" % str(data.get("location", "Unknown"))
    evidence_label.text = "EVIDENCE | %s" % str(data.get("evidence", "Not available"))
    phase_label.text = "STATUS | %s" % str(data.get("phase", "Unreviewed"))
    hint_label.text = str(data.get("hint", "Inspect before taking action."))
    inspect_button.disabled = not bool(data.get("can_inspect", false))
    report_button.disabled = not bool(data.get("can_report", false))
    # Existing civic cards keep their Report action. An owner request has
    # its own explicit gameplay action; the UI cannot invent permissions.
    var report_action: String = str(data.get("report_action", "report"))
    if not ["report", "request_owner"].has(report_action):
        report_action = "report"
    report_button.set_meta("report_action", report_action)
    report_button.text = str(data.get("report_label", "Report to Municipal Service"))

func is_open() -> bool:
    return backdrop != null and backdrop.visible

func dismiss() -> void:
    if not is_open():
        return
    backdrop.visible = false
    dismissed.emit()

func _on_inspect() -> void:
    if is_open() and not inspect_button.disabled:
        action_selected.emit("inspect")

func _on_report() -> void:
    if is_open() and not report_button.disabled:
        action_selected.emit(str(report_button.get_meta("report_action", "report")))

func _input(event: InputEvent) -> void:
    if not is_open():
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        dismiss()
        get_viewport().set_input_as_handled()
