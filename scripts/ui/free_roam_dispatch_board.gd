class_name CivicFreeRoamDispatchBoard
extends CanvasLayer
## GAME-025-02: non-authoritative dispatch board for existing Free Roam.
## This UI never spawns/finishes activities or edits the incident scheduler.
const ModalGuard = preload("res://scripts/ui/civic_modal_input_guard.gd")
signal toggle_requested
signal accept_requested
signal service_requested
signal route_requested

var enabled: bool = false
var expanded: bool = false
var button: Button
var panel: PanelContainer
var heading: Label
var status: Label
var details: Label
var history: Label
var accept_button: Button
var route_button: Button
var service_button: Button
var service_status: Label
var close_button: Button
var content_scroll: ScrollContainer
var content_stack: VBoxContainer
var _focus_before_open: WeakRef
var _feed: Dictionary = {}
var accepted_call_id: int = -1
var service_call_id: int = -1
var response_status: String = ""

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
    content_scroll = ScrollContainer.new()
    content_scroll.name = "DispatchScroll"
    content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    outer.add_child(content_scroll)
    var stack := VBoxContainer.new()
    stack.name = "DispatchContent"
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.add_theme_constant_override("separation", 10)
    content_scroll.add_child(stack)
    content_stack = stack
    var top := HBoxContainer.new()
    stack.add_child(top)
    heading = Label.new()
    heading.text = "MUNICIPAL DISPATCH"
    heading.add_theme_font_size_override("font_size", 18)
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(heading)
    close_button = Button.new()
    close_button.name = "CloseDispatch"
    close_button.text = "CLOSE"
    close_button.custom_minimum_size = Vector2(76, 48)
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
    accept_button = Button.new()
    accept_button.name = "AcceptCall"
    accept_button.text = "ACCEPT CALL"
    accept_button.custom_minimum_size = Vector2(0, 50)
    accept_button.pressed.connect(func() -> void: accept_requested.emit())
    stack.add_child(accept_button)
    route_button = Button.new()
    route_button.name = "ShowRoute"
    route_button.text = "SHOW ON CITY MAP"
    route_button.custom_minimum_size = Vector2(0, 50)
    route_button.pressed.connect(func() -> void: route_requested.emit())
    stack.add_child(route_button)
    service_button = Button.new()
    service_button.name = "RequestService"
    service_button.text = "REQUEST MUNICIPAL SERVICE"
    service_button.custom_minimum_size = Vector2(0, 48)
    service_button.pressed.connect(func() -> void: service_requested.emit())
    stack.add_child(service_button)
    service_status = Label.new()
    service_status.name = "ServiceStatus"
    service_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(service_status)
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
        set_expanded(false)
        accepted_call_id = -1
        service_call_id = -1
        response_status = ""
    _sync_visibility()

func set_expanded(value: bool) -> void:
    var next_expanded: bool = value and enabled
    if expanded == next_expanded:
        _sync_visibility()
        return
    ModalGuard.release_touch_controls(get_tree())
    if next_expanded:
        _focus_before_open = ModalGuard.remember_focus(get_viewport(), panel)
    expanded = next_expanded
    _sync_visibility()
    if expanded:
        if content_scroll != null:
            content_scroll.scroll_vertical = 0
        if close_button != null:
            close_button.grab_focus()
    else:
        ModalGuard.restore_focus(get_viewport(), _focus_before_open, panel)
        _focus_before_open = null

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
    var current_id: int = int(_feed.get("call_id", -1))
    if not active or current_id <= 0 or accepted_call_id != current_id:
        accepted_call_id = -1
    if not active or current_id != service_call_id:
        service_call_id = -1
        response_status = ""
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
    var accepted: bool = active and accepted_call_id == current_id
    accept_button.disabled = not active or current_id <= 0 or accepted
    accept_button.text = "CALL ACCEPTED - TRACKING" if accepted else "ACCEPT CALL"
    route_button.disabled = not accepted or not bool(_feed.get("has_target", false))
    var service_type: String = str(_feed.get("service_type", ""))
    service_button.visible = not service_type.is_empty() and active
    var can_retry: bool = response_status == "SERVICE UNAVAILABLE"
    service_button.disabled = not accepted or service_type.is_empty() or (
        service_call_id == current_id and not can_retry)
    service_button.text = "RETRY " + service_type if can_retry else (
        "REQUEST " + service_type)
    service_status.text = "%s | %s" % [service_type, response_status] if (
        accepted and service_call_id == current_id) else (
        "Accept this call before requesting municipal assistance." if (
            active and not service_type.is_empty()) else "")
    history.text = "VERIFIED ACTIVITIES | %d completed  •  %d expired\nComplete real activities to grow your volunteer record." % [
        int(_feed.get("resolved", 0)), int(_feed.get("expired", 0))]

## Selection is local UI state only. The Free Roam event director
## remains authoritative; accepting cannot start, resolve or reward calls.
func accept_live_call(call_id: int) -> bool:
    if not enabled or call_id <= 0 or not bool(_feed.get("has_event", false)) or (
            int(_feed.get("call_id", -1)) != call_id) or (
            not bool(_feed.get("has_target", false))):
        return false
    accepted_call_id = call_id
    update_feed(_feed)
    return true

func accepted_live_call() -> bool:
    return enabled and accepted_call_id > 0 and (
        accepted_call_id == int(_feed.get("call_id", -1))) and (
        bool(_feed.get("has_event", false))) and bool(_feed.get("has_target", false))

## Informational assistance state, tied to the accepted, actual incident.
func service_requested_for(call_id: int, status: String) -> void:
    if call_id <= 0 or not accepted_live_call() or accepted_call_id != call_id:
        return
    service_call_id = call_id
    response_status = status
    update_feed(_feed)

func _fit() -> void:
    if panel == null:
        return
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    var open_bounds: Rect2 = open_button_bounds(viewport)
    button.position = open_bounds.position
    button.size = open_bounds.size
    var bounds: Rect2 = panel_bounds(viewport)
    panel.position = bounds.position
    panel.size = bounds.size

## Pure presentation geometry; never depends on call or mission state.
static func panel_bounds(viewport: Vector2) -> Rect2:
    if not viewport.is_finite() or viewport.x <= 0.0 or viewport.y <= 0.0:
        return Rect2()
    var margin: float = 8.0
    var width: float = minf(530.0, maxf(0.0, viewport.x - margin * 2.0))
    var height: float = minf(580.0, maxf(0.0, viewport.y - margin * 2.0))
    return Rect2(Vector2((viewport.x - width) * 0.5, (viewport.y - height) * 0.5), Vector2(width, height))

## Keep the CALLS launcher inside the visible viewport after device rotation.
static func open_button_bounds(viewport: Vector2) -> Rect2:
    if not viewport.is_finite() or viewport.x <= 0.0 or viewport.y <= 0.0:
        return Rect2()
    var width: float = minf(92.0, maxf(0.0, viewport.x - 16.0))
    var height: float = minf(44.0, maxf(0.0, viewport.y - 16.0))
    return Rect2(Vector2(maxf(0.0, viewport.x - width - 8.0),
        clampf(viewport.y * 0.60, 8.0, maxf(8.0, viewport.y - height - 8.0))), Vector2(width, height))
