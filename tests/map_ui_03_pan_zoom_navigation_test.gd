extends SceneTree
## MAP-UI-03: full map supports world-accurate pan/zoom on desktop and
## Android without changing the compact minimap, actual mission route,
## or city positions. Tests wheel, drag, pinch, controls and screen bounds.
const Map = preload("res://scripts/ui/civic_city_map.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var area := Rect2(Vector2(10, 25), Vector2(480, 480))
    var center := Vector2.ZERO
    for target in [Vector3(-120, 0, -120), Vector3(0, 0, 0),
            Vector3(46, 0, -46), Vector3(120, 0, 120)]:
        var pixel: Vector2 = Map.full_view_project(target, area, center, 2.0)
        var reverse: Vector2 = Map.full_view_unproject(pixel, area, center, 2.0)
        if reverse.distance_to(Vector2(target.x, target.z)) > 0.01:
            _fail("full map projection cannot round-trip real city coordinates")
            return
    if Map.clamp_map_center(Vector2(999, 999), 1.0) != Vector2.ZERO:
        _fail("at full-city overview the map may pan outside the city")
        return
    if Map.clamp_map_center(Vector2(999, -999), 5.0).distance_to(Vector2(96, -96)) > 0.01:
        _fail("zoomed full map allowed dragging past navigable boundaries")
        return
    var ui: CivicCityMap = Map.new() as CivicCityMap
    root.add_child(ui)
    await process_frame
    ui.set_expanded(true)
    if not ui.large_frame.visible or ui.map_zoom != 1.0 or ui.map_center != Vector2.ZERO:
        _fail("complete initial city overview did not open")
        return
    if ui.zoom_in_button == null or ui.zoom_out_button == null or ui.overview_button == null or ui.recenter_button == null:
        _fail("zoom, whole city and player controls missing")
        return
    ui.zoom_in_button.pressed.emit()
    if not is_equal_approx(ui.map_zoom, Map.MAP_ZOOM_STEP):
        _fail("zoom in button did not change full-map camera")
        return
    ui.zoom_out_button.pressed.emit()
    if not is_equal_approx(ui.map_zoom, 1.0):
        _fail("zoom out button did not show full city")
        return
    var drawing: Rect2 = ui._large_map_rect()
    ui.zoom_at(2.5, drawing.get_center())
    var before: Vector2 = ui.map_center
    ui.pan_pixels(Vector2(-64, 38))
    if ui.map_center.distance_to(before) < 0.2:
        _fail("drag panning did not move map camera")
        return
    var anchor: Vector2 = drawing.get_center() + Vector2(35, -25)
    var world_before: Vector2 = Map.full_view_unproject(anchor, drawing, ui.map_center, ui.map_zoom)
    ui.zoom_at(1.10, anchor)
    var world_after: Vector2 = Map.full_view_unproject(anchor, drawing, ui.map_center, ui.map_zoom)
    if world_before.distance_to(world_after) > 0.1:
        _fail("zoom snapped away from the cursor rather than staying anchored")
        return
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_WHEEL_UP
    mouse.pressed = true
    mouse.position = drawing.get_center()
    var zoom_before: float = ui.map_zoom
    ui._on_large_map_input(mouse)
    if ui.map_zoom <= zoom_before:
        _fail("mouse wheel cannot zoom full city map")
        return
    var left := InputEventMouseButton.new()
    left.button_index = MOUSE_BUTTON_LEFT
    left.pressed = true
    left.position = drawing.get_center()
    ui._on_large_map_input(left)
    var motion := InputEventMouseMotion.new()
    motion.relative = Vector2(35, 0)
    ui._on_large_map_input(motion)
    if not ui._dragging_mouse:
        _fail("mouse drag cannot grab full map")
        return
    left.pressed = false
    ui._on_large_map_input(left)
    if ui._dragging_mouse:
        _fail("mouse drag leaked after button release")
        return
    # Multi-touch on the actual full-map input handler.
    var touch1 := InputEventScreenTouch.new()
    touch1.index = 0
    touch1.pressed = true
    touch1.position = Vector2(120, 120)
    ui._on_large_map_input(touch1)
    var touch2 := InputEventScreenTouch.new()
    touch2.index = 1
    touch2.pressed = true
    touch2.position = Vector2(210, 120)
    ui._on_large_map_input(touch2)
    var pinch := InputEventScreenDrag.new()
    pinch.index = 1
    pinch.position = Vector2(245, 120)
    pinch.relative = Vector2(35, 0)
    zoom_before = ui.map_zoom
    ui._on_large_map_input(pinch)
    if ui.map_zoom <= zoom_before:
        _fail("Android two-finger pinch did not zoom map")
        return
    touch1.pressed = false
    touch2.pressed = false
    ui._on_large_map_input(touch1)
    ui._on_large_map_input(touch2)
    if not ui._touch_points.is_empty():
        _fail("touch tracking did not clear on release")
        return
    ui.update_position(Vector3(-46, 0, 46), Vector3.FORWARD, {
        "title": "Wrong Way", "objective": "Follow evidence",
        "has_target": true, "target": Vector3(46, 0, -46)})
    ui.recenter_button.pressed.emit()
    if ui.map_center.distance_to(Vector2(-46, 46)) > 0.1:
        _fail("CENTER button did not focus the actual player position")
        return
    ui._select_location(0)
    if ui.map_center.distance_to(Vector2.ZERO) > 0.1 or ui.map_zoom < 2.0:
        _fail("selecting a landmark did not navigate map camera there")
        return
    ui.overview_button.pressed.emit()
    if ui.map_zoom != 1.0 or ui.map_center != Vector2.ZERO:
        _fail("ALL button did not restore complete city map")
        return
    ui.set_expanded(false)
    if ui.expanded or not ui.small_frame.visible or not ui._touch_points.is_empty():
        _fail("returning to minimap kept dragging/touch controls active")
        return
    ui.queue_free()
    print("CIVIC_CHAOS_MAP_UI_03_PAN_ZOOM_NAVIGATION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
