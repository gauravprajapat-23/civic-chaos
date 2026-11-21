extends SceneTree
## MAP-002D: adaptive player-up minimap & visibility-aware perf contracts.
const Map = preload("res://scripts/ui/civic_city_map.gd")
const Policy = preload("res://scripts/ui/civic_map_driving_policy.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
var failures: int = 0

func _check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("MAP-002D: " + reason)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(is_equal_approx(Policy.minimap_radius(0.0), 37.0),
        "walking minimap scale was altered")
    _check(Policy.minimap_radius(8.0) > Policy.minimap_radius(1.0),
        "riding does not expand local view")
    _check(is_equal_approx(Policy.minimap_radius(25.0), 72.0),
        "high-speed minimap radius exceeded safe cap")
    _check(is_equal_approx(Policy.minimap_radius(-4.0), 37.0),
        "negative velocity caused invalid zoom")
    _check(Policy.estimated_speed(Vector3.ZERO, Vector3(0, 0, -2), 0.1) == 20.0,
        "sample-based speed estimate incorrect")
    _check(Policy.estimated_speed(Vector3.ZERO, Vector3(0, 0, -2), 1.0) == 0.0,
        "resume from long pause causes zoom spike")
    _check(Policy.draw_minimap(false, true) and
        not Policy.draw_minimap(true, true) and
        not Policy.draw_minimap(false, false),
        "hidden or safe-area-clipped minimap still rendered")
    _check(Policy.draw_full_map(true) and not Policy.draw_full_map(false),
        "hidden expanded map still scheduled for drawing")
    var stable: Dictionary = {"ok": true,
        "points": PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -20)])}
    _check(not Policy.should_refresh_route(Vector3.ZERO, Vector3(0, 0, -1),
        stable, false), "replanned route on tiny movement")
    _check(Policy.should_refresh_route(Vector3.ZERO, Vector3(0, 0, -5),
        stable, false), "moving past refresh distance did not replan")
    _check(Policy.should_refresh_route(Vector3.ZERO, Vector3.ZERO,
        stable, true), "mission/destination change failed to refresh route")

    var area := Rect2(20, 20, 160, 160)
    var center: Vector2 = Map.minimap_project(Vector3.ZERO, Vector3.ZERO,
        Vector3.FORWARD, area, 72.0)
    _check(center.distance_to(area.get_center()) <= 0.001,
        "player displaced from minimap center at driving speed")
    var foot := Map.minimap_project(Vector3(0, 0, -20), Vector3.ZERO,
        Vector3.FORWARD, area)
    var bike := Map.minimap_project(Vector3(0, 0, -20), Vector3.ZERO,
        Vector3.FORWARD, area, 72.0)
    _check(bike.distance_to(area.get_center()) < foot.distance_to(area.get_center()),
        "driving radius does not reveal more road ahead")
    _check(Network.roads().size() == 40,
        "speed-dependent view changed canonical road graph")

    var ui: CivicCityMap = Map.new() as CivicCityMap
    root.add_child(ui)
    await process_frame
    var graph = Builder.make_city_graph()
    ui.set_road_graph(graph)
    var goal: Dictionary = {"title": "Mission", "objective": "Checkpoint",
        "has_target": true, "target": Vector3(0, 0, -46)}
    ui.update_position(Vector3.ZERO, Vector3.FORWARD, goal)
    _check(bool(ui.route_state.get("ok", false)),
        "existing mission GPS route unavailable")
    var initial_route_origin: Vector3 = ui._last_route_origin
    ui.update_position(Vector3(0, 0, -1), Vector3.FORWARD, goal)
    _check(ui._last_route_origin == initial_route_origin,
        "small movement unexpectedly forced full route recalculation")
    _check(ui.player_position == Vector3(0, 0, -1),
        "throttling prevented live player position updates")
    ui.update_position(Vector3(0, 0, -6), Vector3.FORWARD, goal)
    _check(ui._last_route_origin == Vector3(0, 0, -6),
        "route not recalculated after threshold movement")
    ui.set_expanded(true)
    _check(ui.large_frame.visible and not ui.small_frame.visible,
        "expanding map broke mobile canvas visibility")
    ui.set_expanded(false)
    _check(ui.small_frame.visible,
        "collapsed minimap not restored")
    _check(ui.selected_location == -1 and ui.mission_state == goal,
        "driving map policy mutated mission selection")
    ui.queue_free()

    if failures == 0:
        print("CIVIC_CHAOS_MAP_002D_DRIVING_PERFORMANCE_PASS")
    else:
        print("CIVIC_CHAOS_MAP_002D_DRIVING_PERFORMANCE_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
