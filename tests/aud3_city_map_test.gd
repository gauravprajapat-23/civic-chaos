extends SceneTree
## AUD3-MAP-01: city coordinates and mission markers must be real world data.
const Map = preload("res://scripts/ui/civic_city_map.gd")
const Layout = preload("res://scripts/world/city_road_layout.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var square := Rect2(Vector2(10, 20), Vector2(240, 240))
    if Map.world_to_map(Vector3(-120, 0, -120), square).distance_to(Vector2(10, 20)) > 0.01:
        _fail("northwest city corner incorrect")
        return
    if Map.world_to_map(Vector3(120, 0, 120), square).distance_to(Vector2(250, 260)) > 0.01:
        _fail("southeast city corner incorrect")
        return
    if Map.world_to_map(Vector3.ZERO, square).distance_to(Vector2(130, 140)) > 0.01:
        _fail("city center map projection incorrect")
        return
    if Layout.coordinates().size() != 5:
        _fail("map road geometry no longer matches city grid")
        return
    var ui: CivicCityMap = Map.new() as CivicCityMap
    root.add_child(ui)
    await process_frame
    if ui.expanded or ui.large_frame.visible or not ui.small_frame.visible:
        _fail("minimap initial state incorrect")
        return
    var requests := [0]
    ui.toggle_requested.connect(func() -> void: requests[0] += 1)
    ui.map_button.pressed.emit()
    if requests[0] != 1:
        _fail("MAP button did not request full map")
        return
    ui.set_expanded(true)
    if not ui.large_frame.visible or ui.small_frame.visible or ui.map_button.visible:
        _fail("full map overlay did not replace minimap")
        return
    var objective := {"title": "Wrong Way, Wrong Day", "objective": "Find the report post",
        "has_target": true, "target": Vector3(-20, 0, -5.3)}
    ui.update_position(Vector3(2, 0, 3), Vector3.FORWARD, objective)
    if ui.mission_state.get("target") != objective["target"] or not ui.mission_text.text.contains("Wrong Way"):
        _fail("map failed to show actual mission target")
        return
    ui.close_button.pressed.emit()
    if requests[0] != 2:
        _fail("close map button did not request closure")
        return
    ui.set_expanded(false)
    if ui.large_frame.visible or not ui.small_frame.visible:
        _fail("minimap not restored")
        return
    ui.queue_free()
    print("CIVIC_CHAOS_AUD3_CITY_MAP_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
