class_name CivicCityMap
extends CanvasLayer
## AUD3-MAP-01: original live city map, sourced from the actual road layout.
## UI-only: never invent mission positions, routes, reward state or traffic.
signal toggle_requested

const RoadLayout = preload("res://scripts/world/city_road_layout.gd")
const EXTENT: float = RoadLayout.EXTENT_M
const INSET: float = 16.0
const ROAD := Color(0.40, 0.51, 0.57)
const ROAD_EDGE := Color(0.17, 0.25, 0.30)
const PLAYER := Color(0.24, 0.88, 0.96)
const TARGET := Color(1.0, 0.72, 0.20)
const MAP_BACKGROUND := Color(0.075, 0.12, 0.16, 0.96)

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

func _ready() -> void:
    layer = 19
    process_mode = Node.PROCESS_MODE_ALWAYS
    small_frame = PanelContainer.new()
    small_frame.name = "MiniMapFrame"
    small_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(small_frame)
    map_surface = Control.new()
    map_surface.name = "MiniMapDrawing"
    map_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    add_child(large_frame)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 8)
    large_frame.add_child(stack)
    var header := HBoxContainer.new()
    stack.add_child(header)
    var heading := Label.new()
    heading.text = "CIVIC CHAOS  |  CITY MAP"
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_theme_font_size_override("font_size", 22)
    header.add_child(heading)
    close_button = Button.new()
    close_button.name = "CloseCityMap"
    close_button.text = "CLOSE  (M)"
    close_button.custom_minimum_size = Vector2(110, 44)
    close_button.pressed.connect(func() -> void: toggle_requested.emit())
    header.add_child(close_button)
    _map_area = Control.new()
    _map_area.name = "FullMapDrawing"
    _map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _map_area.mouse_filter = Control.MOUSE_FILTER_STOP
    _map_area.draw.connect(_draw_large)
    stack.add_child(_map_area)
    mission_text = Label.new()
    mission_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mission_text.text = "Blue: You   |   Gold: Active objective   |   M: Close map"
    stack.add_child(mission_text)
    get_viewport().size_changed.connect(_fit)
    _fit()
    update_position(Vector3.ZERO, Vector3.FORWARD, {})

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key := event as InputEventKey
        if key.pressed and not key.echo and key.physical_keycode == KEY_M:
            toggle_requested.emit()
            get_viewport().set_input_as_handled()

func set_expanded(value: bool) -> void:
    expanded = value
    if small_frame != null:
        small_frame.visible = not value
    if map_button != null:
        map_button.visible = not value
    if large_frame != null:
        large_frame.visible = value
    if value and close_button != null:
        close_button.grab_focus()
    _redraw()

func update_position(at: Vector3, facing: Vector3, objective: Dictionary) -> void:
    player_position = at
    player_forward = facing
    mission_state = objective.duplicate(true)
    if mission_text != null:
        var objective_title: String = str(objective.get("title", "Explore the city"))
        var description: String = str(objective.get("objective", "Find the next civic task"))
        mission_text.text = "YOU: blue arrow   |   OBJECTIVE: gold pin\n%s  —  %s" % [objective_title, description]
    _redraw()

func _redraw() -> void:
    if map_surface != null:
        map_surface.queue_redraw()
    if _map_area != null:
        _map_area.queue_redraw()

func _fit() -> void:
    if small_frame == null:
        return
    var size: Vector2 = get_viewport().get_visible_rect().size
    var edge: float = minf(150.0, maxf(94.0, size.x * 0.14))
    var center_x: float = size.x * 0.5
    small_frame.position = Vector2(center_x - edge * 0.5, 8)
    small_frame.size = Vector2(edge, edge)
    map_surface.custom_minimum_size = Vector2(edge, edge)
    map_button.position = Vector2(center_x - 48, edge + 16)
    map_button.size = Vector2(96, 44)
    large_frame.position = Vector2(maxf(8, size.x * 0.08), maxf(8, size.y * 0.06))
    large_frame.size = Vector2(maxf(250, size.x * 0.84), maxf(200, size.y * 0.88))
    _redraw()

## Pure transform shared by minimap and full map. North is screen-up (-Z).
static func world_to_map(world: Vector3, area: Rect2) -> Vector2:
    var square: float = minf(area.size.x, area.size.y)
    var origin: Vector2 = area.position + (area.size - Vector2.ONE * square) * 0.5
    return origin + Vector2(
        clampf((world.x + EXTENT) / (EXTENT * 2.0), 0.0, 1.0),
        clampf((world.z + EXTENT) / (EXTENT * 2.0), 0.0, 1.0)
    ) * square

func _draw_small() -> void:
    _draw_map(map_surface, Rect2(Vector2(8, 8), map_surface.size - Vector2(16, 16)), false)

func _draw_large() -> void:
    _draw_map(_map_area, Rect2(Vector2(16, 10), _map_area.size - Vector2(32, 20)), true)

func _draw_map(canvas: Control, requested: Rect2, detailed: bool) -> void:
    if requested.size.x <= 0 or requested.size.y <= 0:
        return
    var size: float = minf(requested.size.x, requested.size.y)
    var area := Rect2(requested.position + (requested.size - Vector2.ONE * size) * 0.5,
        Vector2.ONE * size)
    canvas.draw_rect(area, MAP_BACKGROUND, true)
    var width: float = maxf(2.0, size * RoadLayout.ROAD_WIDTH_M / (EXTENT * 2.0))
    for coordinate in RoadLayout.coordinates():
        var vertical_a := world_to_map(Vector3(coordinate, 0, -EXTENT), area)
        var vertical_b := world_to_map(Vector3(coordinate, 0, EXTENT), area)
        var horizontal_a := world_to_map(Vector3(-EXTENT, 0, coordinate), area)
        var horizontal_b := world_to_map(Vector3(EXTENT, 0, coordinate), area)
        canvas.draw_line(vertical_a, vertical_b, ROAD_EDGE, width + 2.0)
        canvas.draw_line(horizontal_a, horizontal_b, ROAD_EDGE, width + 2.0)
        canvas.draw_line(vertical_a, vertical_b, ROAD, width)
        canvas.draw_line(horizontal_a, horizontal_b, ROAD, width)
    if detailed:
        var center := world_to_map(Vector3.ZERO, area)
        canvas.draw_circle(center, 4.0, Color(0.95, 0.95, 0.95))
    var marker: Variant = mission_state.get("target", null)
    if bool(mission_state.get("has_target", false)) and marker is Vector3:
        var point := world_to_map(marker, area)
        canvas.draw_circle(point, 9.0 if detailed else 5.5, TARGET)
        canvas.draw_arc(point, 13.0 if detailed else 8.0, 0, TAU, 32, TARGET, 2.0)
    var position: Vector2 = world_to_map(player_position, area)
    var facing := Vector2(player_forward.x, player_forward.z)
    if facing.length_squared() < 0.0001:
        facing = Vector2(0, -1)
    facing = facing.normalized()
    var side := Vector2(-facing.y, facing.x)
    var radius: float = 12.0 if detailed else 7.0
    canvas.draw_colored_polygon(PackedVector2Array([
        position + facing * radius, position - facing * radius * 0.6 + side * radius * 0.65,
        position - facing * radius * 0.6 - side * radius * 0.65
    ]), PLAYER)
    canvas.draw_arc(position, radius + 2.0, 0, TAU, 24, Color.WHITE, 1.3)
