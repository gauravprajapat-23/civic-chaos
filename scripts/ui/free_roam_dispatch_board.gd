class_name CivicFreeRoamDispatchBoard
extends CanvasLayer
## GAME-025-02: non-authoritative dispatch board for existing Free Roam.
## This UI never spawns/finishes activities or edits the incident scheduler.
signal toggle_requested
signal route_requested

var enabled: bool = false
var expanded: bool = false
var button: Button
var panel: PanelContainer
var heading: Label
var status: Label
var details: Label
var history: Label
var route_button: Button
var close_button: Button
var _feed: Dictionary = {}

func _ready() -> void:
    layer = 23
    process_mode = Node.PROCESS_MODE_ALWAYS
    button = Button.new()
    button.name = "OpenDispatch"
    button.text = "CALLS"
    button.custom_minimum_size = Vector2(92, 44)
    button.pressed.connect(func() -> void: toggle_requested.emit())
    add_child(button)
    panel = PanelContainer.new()
    panel.name = "DispatchPanel"
    panel.visible = false
    add_child(panel)
    var outer := MarginContainer.new()
    outer.add_theme_constant_override("margin_left", 16)
    outer.add_theme_constant_override("margin_top", 12)
    outer.add_theme_constant_override("margin_right", 16)
    outer.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(outer)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 14)
    outer.add_child(stack)
    var top := HBoxContainer.new()
    stack.add_child(top)
    heading = Label.new()
    heading.text = "MUNICIPAL DISPATCH"
    heading.add_theme_font_size_override("font_size", 22)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(heading)
    close_button = Button.new()
    close_button.name = "CloseDispatch"
    close_button.text = "CLOSE  (F7)"
    close_button.custom_minimum_size = Vector2(115, 48)
    close_button.pressed.connect(func() -> void: toggle_requested.emit())
    top.add_child(close_button)
    status = Label.new()
    status.name = "DispatchStatus"
    status.add_theme_font_size_override("font_size", 19)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(status)
    details = Label.new()
    details.name = "DispatchDetails"
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(details)
    route_button = Button.new()
    route_button.name = "ShowRoute"
    route_button.text = "SHOW ON CITY MAP"
    route_button.custom_minimum_size = Vector2(210, 50)
    route_button.pressed.connect(func() -> void: route_requested.emit())
    stack.add_child(route_button)
    history = Label.new()
    history.name = "DispatchHistory"
    history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(history)
    get_viewport().size_changed.connect(_fit)
    _fit()
    update_feed({})

func _input(event: InputEvent) -> void:
    if not enabled:
        return
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and key.physical_keycode == KEY_F7:
            toggle_requested.emit()
            get_viewport().set_input_as_handled()

func set_available(value: bool) -> void:
    enabled = value
    if not value:
        expanded = false
    _sync_visibility()

func set_expanded(value: bool) -> void:
    expanded = value and enabled
    _sync_visibility()
    if expanded and close_button != null:
        close_button.grab_focus()

func _sync_visibility() -> void:
    if button != null:
        button.visible = enabled and not expanded
    if panel != null:
        panel.visible = enabled and expanded

func update_feed(value: Dictionary) -> void:
    _feed = value.duplicate(true)
    if status == null:
        return
    var active: bool = bool(_feed.get("has_event", false))
    if active:
        status.text = "%s  |  %s" % [
            "PRIORITY CALL" if bool(_feed.get("priority", false)) else "ROUTINE CALL",
            str(_feed.get("title", "Civic activity"))]
        details.text = "LOCATION | %s\nTIME LEFT | %ds\nNEXT ACTION | %s" % [
            str(_feed.get("location", "Market Chowk")), int(_feed.get("seconds_left", 0)),
            str(_feed.get("objective", "Inspect the location"))]
    else:
        status.text = "ALL CLEAR | NO ACTIVE CALL"
        details.text = "Municipal dispatch is monitoring the city.\nNext scheduled opportunity: in %ds.\nExplore streets and neighborhood improvements meanwhile." % int(_feed.get("seconds_until_next", 0))
    route_button.disabled = not active or not bool(_feed.get("has_target", false))
    history.text = "VERIFIED ACTIVITIES | %d completed  •  %d expired\nComplete real activities to grow your volunteer record." % [
        int(_feed.get("resolved", 0)), int(_feed.get("expired", 0))]

func _fit() -> void:
    if panel == null:
        return
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    button.position = Vector2(maxf(8.0, viewport.x - 106.0), maxf(68.0, viewport.y * 0.60))
    button.size = Vector2(92, 44)
    panel.position = Vector2(maxf(8.0, (viewport.x - minf(530.0, viewport.x - 16.0)) * 0.5),
        maxf(12.0, viewport.y * 0.12))
    panel.size = Vector2(minf(530.0, viewport.x - 16.0), minf(430.0, viewport.y * 0.75))
