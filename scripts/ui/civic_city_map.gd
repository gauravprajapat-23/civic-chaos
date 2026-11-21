class_name CivicCityMap
extends CanvasLayer
## AUD3-MAP-01: original live city map, sourced from the actual road layout.
## UI-only: never invent mission positions, routes, reward state or traffic.
signal toggle_requested
const ModalGuard = preload("res://scripts/ui/civic_modal_input_guard.gd")
const SafeLayout = preload("res://scripts/ui/civic_hud_safe_layout.gd")
var _focus_before_open: WeakRef
var hud_safe_area: Rect2 = Rect2()
var hud_exclusions: Array[Rect2] = []

const RoadLayout = preload("res://scripts/world/city_road_layout.gd")
const CityNetwork = preload("res://scripts/world/city_network_definition.gd")
const MapRoutes = preload("res://scripts/ui/civic_map_routes.gd")
const MapStyle = preload("res://scripts/ui/civic_map_visual_style.gd")
const MapDistricts = preload("res://scripts/ui/civic_map_districts.gd")
const NavGuide = preload("res://scripts/ui/civic_map_navigation_guide.gd")
const DrivingPolicy = preload("res://scripts/ui/civic_map_driving_policy.gd")
const LivingZones = preload("res://scripts/world/living_city_zones.gd")
const EXTENT: float = RoadLayout.EXTENT_M
const INSET: float = 16.0
const PLAYER := MapStyle.PLAYER
const TARGET := Color(1.0, 0.72, 0.20)
const MAP_BACKGROUND := MapStyle.BACKGROUND
const ROUTE_COLOR := MapStyle.ROUTE
## Descriptive, grounded map landmarks, not extra missions or unlocks.
const LANDMARKS := [
    {"name": "Market Chowk", "position": Vector3(0, 0, 0)},
    {"name": "West Approach", "position": Vector3(-46, 0, 0)},
    {"name": "East Footpath", "position": Vector3(46, 0, 0)},
    {"name": "North Market Road", "position": Vector3(0, 0, -46)}
]

var player_position: Vector3 = Vector3.ZERO
var player_forward: Vector3 = Vector3.FORWARD
var mission_state: Dictionary = {}
var expanded: bool = false
var map_surface: Control
var small_frame: PanelContainer
var large_frame: PanelContainer
var map_button: Button
var close_button: Button
var mission_text: Label
var _map_area: Control
var road_graph: CivicRoadGraph
var selected_location: int = -1 # -1 means live mission waypoint
var route_state: Dictionary = {}
var _last_route_origin: Vector3 = Vector3.INF
var _last_route_target: Vector3 = Vector3.INF
var _speed_sample_origin: Vector3 = Vector3.INF
var _speed_sample_time_ms: int = -1
var _estimated_speed_mps: float = 0.0
var _minimap_radius_m: float = 37.0
var navigation_label: Label
var guidance_label: Label
var location_buttons: Array[Button] = []
## Full-map camera is UI-only. Minimap and the original overview
## world_to_map() remain unchanged for old navigation contracts.
const MAP_MIN_ZOOM: float = 1.0
const MAP_MAX_ZOOM: float = 5.0
const MAP_ZOOM_STEP: float = 1.25
var map_zoom: float = 1.0
var map_center: Vector2 = Vector2.ZERO # X/Z in world metres
var _touch_points: Dictionary = {}
var _pinch_distance: float = 0.0
var _dragging_mouse: bool = false
var zoom_in_button: Button
var zoom_out_button: Button
var recenter_button: Button
var overview_button: Button

func _ready() -> void:
    layer = 19
    process_mode = Node.PROCESS_MODE_ALWAYS
    small_frame = PanelContainer.new()
    small_frame.name = "MiniMapFrame"
    small_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    small_frame.add_theme_stylebox_override("panel", MapStyle.frame_style())
    add_child(small_frame)
    map_surface = Control.new()
    map_surface.name = "MiniMapDrawing"
    map_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map_surface.clip_contents = true
    map_surface.draw.connect(_draw_small)
    small_frame.add_child(map_surface)
    map_button = Button.new()
    map_button.name = "OpenCityMap"
    map_button.text = "MAP"
    map_button.pressed.connect(func() -> void: toggle_requested.emit())
    add_child(map_button)

    large_frame = PanelContainer.new()
    large_frame.name = "FullCityMap"
    large_frame.visible = false
    large_frame.mouse_filter = Control.MOUSE_FILTER_STOP
    var full_frame_style: StyleBoxFlat = MapStyle.frame_style()
    full_frame_style.set_content_margin_all(8)
    large_frame.add_theme_stylebox_override("panel", full_frame_style)
    add_child(large_frame)
    # UI-002 contract: FullCityMap's direct child remains a VBoxContainer.
    # UI-003: nest scrolling INSIDE that outer box, so rows of controls
    # cannot expand the PanelContainer beyond the safe viewport bounds.
    var outer := VBoxContainer.new()
    outer.name = "FullCityMapLayout"
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    large_frame.add_child(outer)
    var scroll := ScrollContainer.new()
    scroll.name = "FullCityMapScroll"
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    outer.add_child(scroll)
    var stack := VBoxContainer.new()
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_theme_constant_override("separation", 8)
    scroll.add_child(stack)
    var header := HFlowContainer.new()
    header.add_theme_constant_override("h_separation", 5)
    header.add_theme_constant_override("v_separation", 5)
    stack.add_child(header)
    var heading := Label.new()
    heading.text = "CIVIC CHAOS  /  CITY ATLAS"
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_theme_font_size_override("font_size", 18)
    header.add_child(heading)
    zoom_out_button = Button.new()
    zoom_out_button.name = "ZoomOut"
    zoom_out_button.text = "−"
    zoom_out_button.tooltip_text = "Zoom out"
    zoom_out_button.custom_minimum_size = Vector2(44, 44)
    zoom_out_button.pressed.connect(func() -> void: zoom_at(MAP_ZOOM_STEP ** -1.0))
    header.add_child(zoom_out_button)
    zoom_in_button = Button.new()
    zoom_in_button.name = "ZoomIn"
    zoom_in_button.text = "+"
    zoom_in_button.tooltip_text = "Zoom in"
    zoom_in_button.custom_minimum_size = Vector2(44, 44)
    zoom_in_button.pressed.connect(func() -> void: zoom_at(MAP_ZOOM_STEP))
    header.add_child(zoom_in_button)
    overview_button = Button.new()
    overview_button.name = "ShowEntireCity"
    overview_button.text = "ALL"
    overview_button.tooltip_text = "Fit entire city in map view"
    overview_button.custom_minimum_size = Vector2(52, 44)
    overview_button.pressed.connect(reset_full_view)
    header.add_child(overview_button)
    recenter_button = Button.new()
    recenter_button.name = "RecenterMap"
    recenter_button.text = "CENTER"
    recenter_button.tooltip_text = "Center map on your live position"
    recenter_button.custom_minimum_size = Vector2(82, 44)
    recenter_button.pressed.connect(recenter_on_player)
    header.add_child(recenter_button)
    close_button = Button.new()
    close_button.name = "CloseCityMap"
    close_button.text = "CLOSE  (M)"
    close_button.custom_minimum_size = Vector2(110, 44)
    close_button.pressed.connect(func() -> void: toggle_requested.emit())
    header.add_child(close_button)
    _map_area = Control.new()
    _map_area.name = "FullMapDrawing"
    _map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _map_area.custom_minimum_size = Vector2(0, 180)
    _map_area.mouse_filter = Control.MOUSE_FILTER_STOP
    _map_area.clip_contents = true
    _map_area.gui_input.connect(_on_large_map_input)
    _map_area.draw.connect(_draw_large)
    stack.add_child(_map_area)
    var selector := HFlowContainer.new()
    selector.name = "MapLocations"
    selector.add_theme_constant_override("separation", 5)
    stack.add_child(selector)
    var titles: Array[String] = ["MISSION", "CHOWK", "WEST", "EAST", "NORTH"]
    for i in range(titles.size()):
        var location := Button.new()
        location.text = titles[i]
        location.custom_minimum_size = Vector2(58, 42)
        location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        location.pressed.connect(_select_location.bind(i - 1))
        selector.add_child(location)
        location_buttons.append(location)
    var zone_selector := HFlowContainer.new()
    zone_selector.name = "ExplorationZones"
    zone_selector.add_theme_constant_override("separation", 5)
    stack.add_child(zone_selector)
    var zones: Array[Dictionary] = LivingZones.all()
    for index in range(zones.size()):
        var option := Button.new()
        option.name = "Explore_" + str(zones[index]["id"])
        option.text = str(zones[index]["title"]).replace("Community ", "").replace("South ", "")
        option.custom_minimum_size = Vector2(70, 42)
        option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        option.pressed.connect(_select_location.bind(LANDMARKS.size() + index))
        zone_selector.add_child(option)
    for index in range(MapDistricts.SERVICES.size()):
        var service: Dictionary = MapDistricts.SERVICES[index]
        var button := Button.new()
        button.name = "Navigate_" + str(service["id"])
        button.text = str(service["title"]).to_upper()
        button.tooltip_text = "Set GPS destination: " + str(service["title"])
        button.custom_minimum_size = Vector2(90, 42)
        button.pressed.connect(_select_location.bind(
            LANDMARKS.size() + LivingZones.LOCATIONS.size() + index))
        zone_selector.add_child(button)
    navigation_label = Label.new()
    navigation_label.name = "RouteDistance"
    navigation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(navigation_label)
    guidance_label = Label.new()
    guidance_label.name = "GPSGuidance"
    guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    guidance_label.add_theme_color_override("font_color", MapStyle.ROUTE)
    stack.add_child(guidance_label)
    mission_text = Label.new()
    mission_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mission_text.text = "Drag: pan  |  Wheel / +/- / pinch: zoom  |  CENTER: player  |  ALL: entire city"
    stack.add_child(mission_text)
    get_viewport().size_changed.connect(_fit)
    _fit()
    update_position(Vector3.ZERO, Vector3.FORWARD, {})

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        if not key.pressed or key.echo:
            return
        if key.physical_keycode == KEY_M:
            toggle_requested.emit()
            get_viewport().set_input_as_handled()
        elif expanded and key.physical_keycode in [KEY_EQUAL, KEY_KP_ADD]:
            zoom_at(MAP_ZOOM_STEP)
            get_viewport().set_input_as_handled()
        elif expanded and key.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
            zoom_at(1.0 / MAP_ZOOM_STEP)
            get_viewport().set_input_as_handled()

func set_expanded(value: bool) -> void:
    # Always discard a captured pan/pinch on a real modal transition.
    if expanded == value:
        return
    ModalGuard.release_touch_controls(get_tree())
    if value:
        _focus_before_open = ModalGuard.remember_focus(get_viewport(), large_frame)
    expanded = value
    _dragging_mouse = false
    _touch_points.clear()
    _pinch_distance = 0.0
    if small_frame != null:
        small_frame.visible = not value and small_frame.size.x > 0.0
    if map_button != null:
        map_button.visible = not value and map_button.size.x >= 44.0 and map_button.size.y >= 44.0
    if large_frame != null:
        large_frame.visible = value
    if value:
        if close_button != null:
            close_button.grab_focus()
    else:
        ModalGuard.restore_focus(get_viewport(), _focus_before_open, large_frame)
        _focus_before_open = null
    _redraw()

## Camera conversion for the panning/zooming full map.
## Unclamped projection is intentional: clipping, not clamping, avoids
## drawing off-screen distant roads and pins on the viewport border.
static func full_view_project(world: Vector3, area: Rect2,
        center: Vector2, zoom: float) -> Vector2:
    var square: float = minf(area.size.x, area.size.y)
    return area.get_center() + (
        Vector2(world.x, world.z) - center
    ) * (square / (EXTENT * 2.0)) * clampf(zoom, MAP_MIN_ZOOM, MAP_MAX_ZOOM)

static func full_view_unproject(pixel: Vector2, area: Rect2,
        center: Vector2, zoom: float) -> Vector2:
    var square: float = minf(area.size.x, area.size.y)
    if square <= 0.0:
        return center
    return center + (pixel - area.get_center()) * (
        EXTENT * 2.0 / (square * clampf(zoom, MAP_MIN_ZOOM, MAP_MAX_ZOOM)))

static func clamp_map_center(center: Vector2, zoom: float) -> Vector2:
    var bound: float = EXTENT * (1.0 - 1.0 / clampf(zoom, MAP_MIN_ZOOM, MAP_MAX_ZOOM))
    return Vector2(clampf(center.x, -bound, bound), clampf(center.y, -bound, bound))

func _large_map_rect() -> Rect2:
    # Headless tests and the first frame after opening may run before
    # Godot's container layout gives FullMapDrawing a nonzero size.
    # Use a stable positive viewport-relative rectangle until layout
    # settles, instead of silently ignoring zoom and drag input.
    var drawing_size: Vector2 = _map_area.size if _map_area != null else Vector2.ZERO
    if drawing_size.x <= 32.0 or drawing_size.y <= 20.0:
        var viewport_size: Vector2 = get_viewport().get_visible_rect().size
        drawing_size = Vector2(maxf(280.0, viewport_size.x * 0.84 - 32.0),
            maxf(220.0, viewport_size.y * 0.65))
    var available := Rect2(Vector2(16, 10), drawing_size - Vector2(32, 20))
    var square: float = minf(available.size.x, available.size.y)
    return Rect2(available.position + (available.size - Vector2.ONE * square) * 0.5,
        Vector2.ONE * square)

func pan_pixels(delta: Vector2) -> void:
    if _map_area == null:
        return
    var area: Rect2 = _large_map_rect()
    if area.size.x <= 0.0:
        return
    # Dragging the map right moves the viewed geographic center left.
    map_center = clamp_map_center(
        map_center - delta * (EXTENT * 2.0 / (area.size.x * map_zoom)),
        map_zoom)
    _redraw()

func zoom_at(multiplier: float, anchor: Vector2 = Vector2.INF) -> void:
    if not is_finite(multiplier) or multiplier <= 0.0 or _map_area == null:
        return
    var area: Rect2 = _large_map_rect()
    if area.size.x <= 0.0:
        return
    var pivot: Vector2 = anchor if anchor.is_finite() else area.get_center()
    var before: Vector2 = full_view_unproject(pivot, area, map_center, map_zoom)
    var new_zoom: float = clampf(map_zoom * multiplier, MAP_MIN_ZOOM, MAP_MAX_ZOOM)
    var afterward: Vector2 = full_view_unproject(pivot, area, map_center, new_zoom)
    map_zoom = new_zoom
    map_center = clamp_map_center(map_center + before - afterward, map_zoom)
    _redraw()

func recenter_on_player() -> void:
    # One button returns to the complete city view, or follows player
    # at the existing zoom after pressing CENTER again.
    map_center = clamp_map_center(Vector2(player_position.x, player_position.z), map_zoom)
    _redraw()

func reset_full_view() -> void:
    map_zoom = MAP_MIN_ZOOM
    map_center = Vector2.ZERO
    _redraw()

func _on_large_map_input(event: InputEvent) -> void:
    if not expanded:
        return
    if event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
            zoom_at(MAP_ZOOM_STEP, mouse.position)
            _map_area.accept_event()
        elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
            zoom_at(1.0 / MAP_ZOOM_STEP, mouse.position)
            _map_area.accept_event()
        elif mouse.button_index == MOUSE_BUTTON_LEFT:
            _dragging_mouse = mouse.pressed
            _map_area.accept_event()
    elif event is InputEventMouseMotion and _dragging_mouse:
        pan_pixels((event as InputEventMouseMotion).relative)
        _map_area.accept_event()
    elif event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _touch_points[touch.index] = touch.position
        else:
            _touch_points.erase(touch.index)
        _pinch_distance = _touch_separation()
        _map_area.accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if not _touch_points.has(drag.index):
            return
        _touch_points[drag.index] = drag.position
        if _touch_points.size() == 1:
            pan_pixels(drag.relative)
        elif _touch_points.size() == 2:
            var distance: float = _touch_separation()
            if _pinch_distance > 1.0 and distance > 1.0:
                var anchor: Vector2 = (_touch_points.values()[0] + _touch_points.values()[1]) * 0.5
                zoom_at(distance / _pinch_distance, anchor)
            _pinch_distance = distance
        _map_area.accept_event()

func _touch_separation() -> float:
    if _touch_points.size() != 2:
        return 0.0
    var positions: Array = _touch_points.values()
    return (positions[0] as Vector2).distance_to(positions[1] as Vector2)

func update_position(at: Vector3, facing: Vector3, objective: Dictionary) -> void:
    # Measure speed over a stable interval rather than every frame.
    var ticks_ms: int = Time.get_ticks_msec()
    if _speed_sample_time_ms < 0 or not _speed_sample_origin.is_finite():
        _speed_sample_origin = at
        _speed_sample_time_ms = ticks_ms
    else:
        var sample_s: float = float(ticks_ms - _speed_sample_time_ms) / 1000.0
        if sample_s >= 0.09:
            _estimated_speed_mps = DrivingPolicy.estimated_speed(
                _speed_sample_origin, at, sample_s)
            _speed_sample_origin = at
            _speed_sample_time_ms = ticks_ms
    _minimap_radius_m = DrivingPolicy.minimap_radius(_estimated_speed_mps)
    player_position = at
    player_forward = facing
    mission_state = objective.duplicate(true)
    var goal: Dictionary = _navigation_goal()
    var target: Vector3 = goal.get("target", Vector3.INF)
    if DrivingPolicy.should_refresh_route(_last_route_origin, at, route_state,
            target != _last_route_target):
        _update_route()
    else:
        _refresh_guidance_label()
    if mission_text != null:
        var objective_title: String = str(objective.get("title", "Explore the city"))
        var description: String = str(objective.get("objective", "Find the next civic task"))
        mission_text.text = "YOU: blue arrow   |   OBJECTIVE: gold pin\n%s  —  %s" % [objective_title, description]
    _redraw()

func set_road_graph(graph: CivicRoadGraph) -> void:
    road_graph = graph
    _update_route()

func _select_location(index: int) -> void:
    selected_location = index
    _update_route()
    if expanded and selected_location >= 0:
        var goal: Dictionary = _navigation_goal()
        if bool(goal.get("has_target", false)):
            map_zoom = maxf(map_zoom, 2.0)
            var target: Vector3 = goal["target"]
            map_center = clamp_map_center(Vector2(target.x, target.z), map_zoom)
    _redraw()

func _navigation_goal() -> Dictionary:
    if selected_location >= 0 and selected_location < LANDMARKS.size():
        return {"has_target": true, "target": LANDMARKS[selected_location]["position"],
            "title": LANDMARKS[selected_location]["name"]}
    var zone_index: int = selected_location - LANDMARKS.size()
    if zone_index >= 0 and zone_index < LivingZones.LOCATIONS.size():
        var zone: Dictionary = LivingZones.LOCATIONS[zone_index]
        return {"has_target": true, "target": zone["position"], "title": zone["title"]}
    var service_index: int = zone_index - LivingZones.LOCATIONS.size()
    if service_index >= 0 and service_index < MapDistricts.SERVICES.size():
        var service: Dictionary = MapDistricts.SERVICES[service_index]
        return {"has_target": true, "target": service["position"], "title": service["title"]}
    var target: Variant = mission_state.get("target", null)
    if bool(mission_state.get("has_target", false)) and target is Vector3:
        return {"has_target": true, "target": target, "title": str(mission_state.get("title", "Active mission"))}
    return {"has_target": false, "title": "No active waypoint"}

func _update_route() -> void:
    var destination: Dictionary = _navigation_goal()
    _last_route_origin = player_position
    _last_route_target = destination.get("target", Vector3.INF)
    route_state = {}
    if bool(destination.get("has_target", false)) and road_graph != null:
        route_state = MapRoutes.plan(road_graph, player_position, destination["target"])
    _refresh_guidance_label()

func _refresh_guidance_label() -> void:
    var destination: Dictionary = _navigation_goal()
    if navigation_label != null:
        if not bool(destination.get("has_target", false)):
            navigation_label.text = "No location selected. Choose a landmark to explore."
        elif bool(route_state.get("ok", false)):
            navigation_label.text = "%s  |  Road route: %d m  |  Direct: %d m" % [
                str(destination["title"]), int(roundf(float(route_state["distance_m"]))),
                int(roundf(float(route_state["direct_m"])))]
        else:
            navigation_label.text = "%s  |  Road route unavailable" % str(destination["title"])
    if guidance_label != null:
        var guide: Dictionary = NavGuide.guidance(route_state, player_position)
        guidance_label.text = "GPS  /  %s" % str(guide["instruction"])
        if bool(guide.get("available", false)) and str(guide.get("turn", "")) != "arrive":
            guidance_label.text += "  /  %d m remaining" % int(roundf(
                float(guide.get("remaining_m", 0.0))))

func _redraw() -> void:
    # Do not redraw the hidden 40-road atlas each player movement tick.
    if map_surface != null and DrivingPolicy.draw_minimap(
            expanded, small_frame != null and small_frame.visible):
        map_surface.queue_redraw()
    if _map_area != null and DrivingPolicy.draw_full_map(expanded):
        _map_area.queue_redraw()

## UI-HUD-01: deterministic screen-space placement, clear of mobile
## bottom touch controls and safe areas. The full map is unchanged.
static func minimap_bounds(viewport: Vector2) -> Rect2:
    if not viewport.is_finite() or viewport.x < 240.0 or viewport.y < 240.0:
        return Rect2()
    var edge: float = minf(156.0, maxf(100.0, minf(viewport.x * 0.22, viewport.y * 0.25)))
    var bottom_safe: float = 16.0 if viewport.x >= 700.0 else 74.0
    return Rect2(Vector2(12.0, viewport.y - bottom_safe - edge - 38.0), Vector2(edge, edge))

## Main may pass Godot safe-area coordinates plus live mobile touch rectangles.
## These affect only geometry, never the selected route or mission state.
func set_hud_constraints(safe_area: Rect2, exclusions: Array[Rect2] = []) -> void:
    hud_safe_area = safe_area
    hud_exclusions = exclusions.duplicate()
    _fit()

func _fit() -> void:
    if small_frame == null:
        return
    var size: Vector2 = get_viewport().get_visible_rect().size
    var bounds: Rect2 = SafeLayout.minimap(size, hud_safe_area, hud_exclusions)
    small_frame.position = bounds.position
    small_frame.size = bounds.size
    small_frame.visible = not expanded and bounds.has_area()
    map_surface.custom_minimum_size = bounds.size
    map_button.position = Vector2(bounds.position.x, bounds.end.y + 4.0)
    map_button.size = Vector2(bounds.size.x, 44.0) if bounds.has_area() else Vector2.ZERO
    map_button.visible = not expanded and bounds.has_area()
    var full_bounds: Rect2 = SafeLayout.panel(size, size * 0.94, hud_safe_area)
    large_frame.position = full_bounds.position
    large_frame.size = full_bounds.size
    _redraw()

## Pure transform shared by minimap and full map. North is screen-up (-Z).
static func world_to_map(world: Vector3, area: Rect2) -> Vector2:
    var square: float = minf(area.size.x, area.size.y)
    var origin: Vector2 = area.position + (area.size - Vector2.ONE * square) * 0.5
    return origin + Vector2(
        clampf((world.x + EXTENT) / (EXTENT * 2.0), 0.0, 1.0),
        clampf((world.z + EXTENT) / (EXTENT * 2.0), 0.0, 1.0)
    ) * square

## Player-centred square minimap, oriented with actual player heading.
## Only the full map uses the global overview/world_to_map projection.
const MINI_RADIUS_M: float = 37.0

static func minimap_project(world: Vector3, player_at: Vector3,
        player_facing: Vector3, area: Rect2,
        radius_m: float = MINI_RADIUS_M) -> Vector2:
    var forward := Vector2(player_facing.x, player_facing.z)
    if forward.length_squared() < 0.0001:
        forward = Vector2(0, -1)
    forward = forward.normalized()
    var right := Vector2(-forward.y, forward.x)
    var delta := Vector2(world.x - player_at.x, world.z - player_at.z)
    var local := Vector2(delta.dot(right), -delta.dot(forward))
    return area.get_center() + local * minf(area.size.x, area.size.y) / (
        maxf(1.0, radius_m) * 2.0)

func _draw_small() -> void:
    if map_surface == null:
        return
    var area := Rect2(Vector2(7, 7), map_surface.size - Vector2(14, 14))
    if area.size.x <= 0.0 or area.size.y <= 0.0:
        return
    map_surface.draw_rect(area, MAP_BACKGROUND, true)
    map_surface.draw_rect(area.grow(-2.0), MapStyle.BLOCK_TINT, false, 1.0)
    _draw_district_regions(map_surface, area, true)
    # Draw exactly the canonical network used by drivable road geometry.
    # Each road centerline is sampled, not replaced by grid-axis chords.
    for road in CityNetwork.roads():
        var points: PackedVector3Array = road["centerline"]
        var road_width: float = MapStyle.road_width(road,
            minf(area.size.x, area.size.y) / (_minimap_radius_m * 2.0), true)
        for i in range(1, points.size()):
            var a: Vector2 = minimap_project(points[i - 1],
                player_position, player_forward, area, _minimap_radius_m)
            var b: Vector2 = minimap_project(points[i],
                player_position, player_forward, area, _minimap_radius_m)
            if not MapStyle.segment_visible(a, b, area, road_width):
                continue
            map_surface.draw_line(a, b, MapStyle.road_edge(road), road_width + 2.6, true)
            map_surface.draw_line(a, b, MapStyle.road_color(road), road_width, true)
    _draw_district_pois(map_surface, area, true)
    _draw_challenge_indicators(map_surface, area, true)
    if bool(route_state.get("ok", false)):
        var path: PackedVector3Array = route_state["points"]
        for i in range(1, path.size()):
            var a: Vector2 = minimap_project(path[i - 1], player_position, player_forward, area, _minimap_radius_m)
            var b: Vector2 = minimap_project(path[i], player_position, player_forward, area, _minimap_radius_m)
            if MapStyle.segment_visible(a, b, area):
                map_surface.draw_line(a, b, MapStyle.ROUTE_HALO, 5.5, true)
                map_surface.draw_line(a, b, ROUTE_COLOR, 3.0, true)
    var destination: Dictionary = _navigation_goal()
    if bool(destination.get("has_target", false)):
        var target: Vector2 = minimap_project(destination["target"], player_position, player_forward, area, _minimap_radius_m)
        target = Vector2(clampf(target.x, area.position.x + 5.0, area.end.x - 5.0),
            clampf(target.y, area.position.y + 5.0, area.end.y - 5.0))
        map_surface.draw_circle(target, 5.0, NavGuide.marker_color(
            "mission" if selected_location == -1 else "explore"))
    var center: Vector2 = area.get_center()
    map_surface.draw_circle(center, 11.0, MapStyle.ROUTE_HALO)
    map_surface.draw_colored_polygon(MapStyle.player_triangle(center, Vector2.UP, 8.0), PLAYER)
    map_surface.draw_arc(center, 11.0, 0, TAU, 24, Color.WHITE, 1.4)
    # Orientation remains player-up; never label the top edge as north.
    map_surface.draw_string(ThemeDB.fallback_font, area.position + Vector2(6, 14),
        "LOCAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.84, 0.86))
    if bool(route_state.get("ok", false)):
        var guide: Dictionary = NavGuide.guidance(route_state, player_position)
        var hint: String = str(guide.get("instruction", ""))
        # The driving minimap stays readable; detailed guidance remains
        # in the expandable map, not a large overlapping HUD banner.
        map_surface.draw_rect(Rect2(area.position.x + 2, area.end.y - 21,
            area.size.x - 4, 19), MapStyle.ROUTE_HALO, true)
        map_surface.draw_string(ThemeDB.fallback_font,
            Vector2(area.position.x + 7, area.end.y - 7),
            hint, HORIZONTAL_ALIGNMENT_LEFT, int(area.size.x - 14), 10, ROUTE_COLOR)

## MAP-002B map overlays: non-colliding filled blocks remain BEHIND
## canonical streets. Both projections use the same original world poses.
func _district_project(world: Vector3, area: Rect2, small: bool) -> Vector2:
    if small:
        return minimap_project(world, player_position, player_forward, area, _minimap_radius_m)
    return full_view_project(world, area, map_center, map_zoom)

func _draw_district_regions(canvas: Control, area: Rect2, small: bool) -> void:
    for region in MapDistricts.REGIONS:
        var points: PackedVector2Array = MapDistricts.project_polygon(
            region, _district_project.bind(area, small))
        if not MapDistricts.visible(points, area):
            continue
        var fill: Color = region["fill"]
        # Keep mini translucent enough that real roadway takes priority.
        fill.a *= 0.52 if small else 1.0
        canvas.draw_colored_polygon(points, fill)
        if not small:
            var center: Vector2 = _district_project(region["center"], area, false)
            if area.has_point(center):
                canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-32, -10),
                    str(region["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1,
                    9 if map_zoom < 1.6 else 11,
                    Color(0.79, 0.89, 0.88, 0.82))

func _draw_district_pois(canvas: Control, area: Rect2, small: bool) -> void:
    for poi in MapDistricts.SERVICES:
        var spot: Vector2 = _district_project(poi["position"], area, small)
        if not area.has_point(spot):
            continue
        var radius: float = 5.0 if small else 8.0
        canvas.draw_circle(spot, radius + 1.5, MapStyle.ROUTE_HALO)
        canvas.draw_circle(spot, radius, NavGuide.marker_color("service"))
        if not small:
            canvas.draw_string(ThemeDB.fallback_font, spot + Vector2(-3, 4),
                str(poi["symbol"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
        if not small:
            canvas.draw_string(ThemeDB.fallback_font,
                spot + Vector2(radius + 4.0, 4.0), str(poi["title"]),
                HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.90, 0.97, 0.98))

## Show the player which otherwise-simple grid segments have real S-bends.
## The warning pins are deterministic and do not change navigation state.
func _draw_challenge_indicators(canvas: Control, area: Rect2, small: bool) -> void:
    for section in RoadLayout.challenge_segments():
        var position: Vector3 = (section["start"] + section["end"]) * 0.5
        var spot: Vector2 = minimap_project(position, player_position, player_forward, area, _minimap_radius_m) if small else world_to_map(position, area)
        if not area.has_point(spot):
            continue
        var radius: float = 2.8 if small else 4.8
        canvas.draw_circle(spot, radius + 1.0, Color(0.11, 0.12, 0.14))
        canvas.draw_circle(spot, radius, Color(1.0, 0.75, 0.13))

func _draw_large() -> void:
    _draw_map(_map_area, _large_map_rect(), true)

func _draw_full_challenge_indicators(canvas: Control, area: Rect2) -> void:
    for section in RoadLayout.challenge_segments():
        var position: Vector3 = (section["start"] + section["end"]) * 0.5
        var point: Vector2 = full_view_project(position, area, map_center, map_zoom)
        if area.has_point(point):
            canvas.draw_circle(point, 4.8, TARGET)

func _draw_map(canvas: Control, requested: Rect2, detailed: bool) -> void:
    if requested.size.x <= 0 or requested.size.y <= 0:
        return
    var size: float = minf(requested.size.x, requested.size.y)
    var area := Rect2(requested.position + (requested.size - Vector2.ONE * size) * 0.5,
        Vector2.ONE * size)
    canvas.draw_rect(area, MAP_BACKGROUND, true)
    # Restrained cartographic frame, no fabricated streets or parcels.
    canvas.draw_rect(area.grow(-3.0), MapStyle.BLOCK_TINT, false, 1.0)
    _draw_district_regions(canvas, area, false)
    # Same source-of-truth as the vehicle graph and physical curved asphalt:
    # no invented straight roads between the canonical street nodes.
    for road in CityNetwork.roads():
        var points: PackedVector3Array = road["centerline"]
        var width: float = MapStyle.road_width(road,
            size / (EXTENT * 2.0) * map_zoom, false)
        for i in range(1, points.size()):
            var a: Vector2 = full_view_project(points[i - 1], area,
                map_center, map_zoom)
            var b: Vector2 = full_view_project(points[i], area,
                map_center, map_zoom)
            if not MapStyle.segment_visible(a, b, area, width):
                continue
            canvas.draw_line(a, b, MapStyle.road_edge(road), width + 3.0, true)
            canvas.draw_line(a, b, MapStyle.road_color(road), width, true)
    _draw_district_pois(canvas, area, false)
    _draw_full_challenge_indicators(canvas, area)
    if bool(route_state.get("ok", false)):
        var path: PackedVector3Array = route_state["points"]
        for index in range(1, path.size()):
            var a: Vector2 = full_view_project(path[index - 1], area, map_center, map_zoom)
            var b: Vector2 = full_view_project(path[index], area, map_center, map_zoom)
            if MapStyle.segment_visible(a, b, area):
                canvas.draw_line(a, b, MapStyle.ROUTE_HALO, 8.0 if detailed else 5.0, true)
                canvas.draw_line(a, b, ROUTE_COLOR, 4.3 if detailed else 2.5, true)
    if detailed:
        canvas.draw_string(ThemeDB.fallback_font, area.position + Vector2(12, 18),
            "MARKET ROADS   /   COLLECTOR STREETS",
            HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.87, 0.85))
        canvas.draw_string(ThemeDB.fallback_font, area.position + Vector2(12, 33),
            "N  ^     DRAG TO PAN  /  SCROLL TO ZOOM",
            HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.60, 0.76, 0.79))
        var font: Font = ThemeDB.fallback_font
        for landmark in LANDMARKS:
            var center: Vector2 = full_view_project(landmark["position"], area, map_center, map_zoom)
            canvas.draw_circle(center, 4.5, Color(0.93, 0.93, 0.95))
            canvas.draw_string(font, center + Vector2(7, -7), str(landmark["name"]),
                HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.96, 0.97, 0.99))
        for zone in LivingZones.LOCATIONS:
            var mark: Vector2 = full_view_project(zone["position"], area, map_center, map_zoom)
            canvas.draw_circle(mark, 5.5, zone["color"])
            canvas.draw_string(font, mark + Vector2(8, 15), str(zone["title"]),
                HORIZONTAL_ALIGNMENT_LEFT, -1, 11, zone["color"])
    var marker: Variant = mission_state.get("target", null)
    if bool(mission_state.get("has_target", false)) and marker is Vector3:
        var point := full_view_project(marker, area, map_center, map_zoom)
        var mission_color: Color = NavGuide.marker_color("mission")
        canvas.draw_circle(point, 9.0 if detailed else 5.5, mission_color)
        canvas.draw_arc(point, 13.0 if detailed else 8.0, 0, TAU, 32, mission_color, 2.0)
    var position: Vector2 = full_view_project(player_position, area, map_center, map_zoom)
    var facing := Vector2(player_forward.x, player_forward.z)
    if facing.length_squared() < 0.0001:
        facing = Vector2(0, -1)
    facing = facing.normalized()
    var radius: float = 12.0 if detailed else 7.0
    canvas.draw_circle(position, radius + 3.0, MapStyle.ROUTE_HALO)
    canvas.draw_colored_polygon(MapStyle.player_triangle(position, facing, radius), PLAYER)
    canvas.draw_arc(position, radius + 3.0, 0, TAU, 24, Color.WHITE, 1.4)

## A device can rotate while MAP is open; never push the full frame offscreen.
static func expanded_bounds(viewport: Vector2) -> Rect2:
    if not viewport.is_finite() or viewport.x <= 0.0 or viewport.y <= 0.0:
        return Rect2()
    var margin: float = 8.0
    var width: float = minf(viewport.x - margin * 2.0, viewport.x * 0.92)
    var height: float = minf(viewport.y - margin * 2.0, viewport.y * 0.94)
    return Rect2((viewport - Vector2(width, height)) * 0.5, Vector2(width, height))
