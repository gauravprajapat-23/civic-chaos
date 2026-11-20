extends SceneTree
## MAP-002C: purely informational GPS, known-place selection, route
## stability and existing city map controls.
const Map = preload("res://scripts/ui/civic_city_map.gd")
const Guide = preload("res://scripts/ui/civic_map_navigation_guide.gd")
const Districts = preload("res://scripts/ui/civic_map_districts.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
var failures: int = 0

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("MAP-002C: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var missing: Dictionary = Guide.guidance({}, Vector3.ZERO)
    _check(not bool(missing.get("available", false)),
        "missing graph presented fake route")
    var straight: Dictionary = {"ok": true, "points": PackedVector3Array([
        Vector3(0, 0, 0), Vector3(0, 0, -20), Vector3(0, 0, -80)])}
    var cue: Dictionary = Guide.guidance(straight, Vector3(0, 0, -4))
    _check(bool(cue.get("available", false)) and
        str(cue.get("turn", "")) == "straight", "straight route produced false turn")
    _check(absf(float(cue.get("remaining_m", -1.0)) - 76.0) < 0.1,
        "remaining distance not measured from live position")
    var right: Dictionary = {"ok": true, "points": PackedVector3Array([
        Vector3(0, 0, 0), Vector3(0, 0, -20), Vector3(30, 0, -20)])}
    var turn: Dictionary = Guide.guidance(right, Vector3(0, 0, -5))
    _check(str(turn.get("turn", "")) == "right" and
        str(turn.get("instruction", "")).contains("Turn right"),
        "right turn guidance incorrect")
    var left: Dictionary = {"ok": true, "points": PackedVector3Array([
        Vector3(0, 0, 0), Vector3(0, 0, -20), Vector3(-30, 0, -20)])}
    _check(str(Guide.guidance(left, Vector3(0, 0, -5)).get("turn", "")) == "left",
        "left turn guidance incorrect")
    _check(str(Guide.guidance(right, Vector3(30, 0, -20)).get("turn", "")) == "arrive",
        "arrived route continues prompting movement")
    _check(str(Guide.guidance(right, Vector3(40, 0, -5)).get("turn", "")) == "rejoin",
        "off-route position shown as safe driving cue")
    var markers: Array[Dictionary] = Districts.services()
    var projector := func(world: Vector3) -> Vector2:
        return Vector2(world.x, world.z)
    var first: Vector3 = markers[0]["position"]
    _check(Guide.nearest_marker(Vector2(first.x, first.z), markers, projector) == 0,
        "selecting known bus-stop location failed")
    _check(Guide.nearest_marker(Vector2(999, 999), markers, projector) == -1,
        "empty map point falsely selected landmark")
    var ui: CivicCityMap = Map.new() as CivicCityMap
    root.add_child(ui)
    await process_frame
    var graph: CivicRoadGraph = Builder.make_city_graph()
    ui.set_road_graph(graph)
    ui.update_position(Vector3(-90, 0, 0), Vector3.FORWARD, {})
    _check(ui.guidance_label != null, "GPS label not created")
    _check(ui.find_child("Navigate_bus_stop", true, false) is Button and
        ui.find_child("Navigate_parking", true, false) is Button,
        "real service destinations missing selectable controls")
    var before: Dictionary = ui.mission_state.duplicate(true)
    var bus_button := ui.find_child("Navigate_bus_stop", true, false) as Button
    if bus_button != null:
        bus_button.pressed.emit()
        _check(str(ui._navigation_goal().get("title", "")) == "Old Bus Stop",
            "bus stop selection not mapped to real world landmark")
        _check(bool(ui.route_state.get("ok", false)),
            "navigation didn't use real road graph")
        _check(ui.guidance_label.text.begins_with("GPS  /"),
            "selected waypoint not reflected in GPS cue")
    _check(ui.mission_state == before,
        "GPS selection changed active mission state")
    ui._select_location(-1)
    _check(ui.selected_location == -1, "mission waypoint restoration failed")
    ui.set_expanded(true)
    ui.zoom_at(1.25)
    _check(ui.expanded and ui.map_zoom > 1.0,
        "GPS overlay broke full-map zoom")
    ui.set_expanded(false)
    _check(ui.small_frame.visible, "GPS overlay broke minimap restoration")
    ui.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_MAP_002C_GPS_NAVIGATION_PASS")
    else:
        print("CIVIC_CHAOS_MAP_002C_GPS_NAVIGATION_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
