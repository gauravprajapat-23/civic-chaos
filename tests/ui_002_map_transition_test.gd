extends SceneTree
## UI-002: map gesture release, modal focus and portrait/landscape bounds.
const MapUI = preload("res://scripts/ui/civic_city_map.gd")
const Controls = preload("res://scripts/ui/touch_controls.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var home := Button.new()
    home.name = "FocusBeforeMap"
    root.add_child(home)
    var controls: CivicTouchControls = Controls.new() as CivicTouchControls
    root.add_child(controls)
    var map: CivicCityMap = MapUI.new() as CivicCityMap
    root.add_child(map)
    await process_frame
    home.grab_focus()
    for cycle in range(3):
        Input.action_press("jump")
        map.set_expanded(true)
        if Input.is_action_pressed("jump") or not map.large_frame.visible:
            _fail("MAP did not release retained action on open")
            return
        map._touch_points[7] = Vector2(60, 60)
        map._pinch_distance = 32.0
        map._dragging_mouse = true
        map.set_expanded(true)
        map.set_expanded(false)
        if not map._touch_points.is_empty() or map._pinch_distance != 0.0 or map._dragging_mouse:
            _fail("MAP close retained pan or pinch gesture")
            return
        if root.gui_get_focus_owner() != home:
            _fail("MAP did not restore previous focus")
            return
    map.set_expanded(true)
    home.hide()
    map.set_expanded(false)
    if root.gui_get_focus_owner() == home:
        _fail("MAP returned focus to hidden button")
        return
    for viewport in [Vector2(320, 568), Vector2(740, 360), Vector2(360, 740), Vector2(568, 320)]:
        var area := Rect2(Vector2.ZERO, viewport)
        if not area.encloses(MapUI.expanded_bounds(viewport)):
            _fail("MAP escaped viewport: " + str(viewport))
            return
    if MapUI.expanded_bounds(Vector2.ZERO) != Rect2():
        _fail("MAP accepted invalid viewport")
        return
    if not (map.large_frame.get_child(0) is VBoxContainer):
        _fail("MAP layout contract changed unexpectedly")
        return
    map.queue_free()
    controls.queue_free()
    home.queue_free()
    print("CIVIC_CHAOS_UI_002_MAP_TRANSITION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
