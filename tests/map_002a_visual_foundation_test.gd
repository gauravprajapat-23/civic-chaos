extends SceneTree
## MAP-002A: road-class visual hierarchy must stay projection-only,
## preserving WORLD-001E geometry and the existing map UI contracts.
const Map = preload("res://scripts/ui/civic_city_map.gd")
const Style = preload("res://scripts/ui/civic_map_visual_style.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
const Organic = preload("res://scripts/world/organic_road_geometry.gd")
var failures: int = 0

func _check(ok: bool, why: String) -> void:
    if not ok:
        failures += 1
        push_error("MAP-002A: " + why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var roads: Array[Dictionary] = Network.roads()
    _check(roads.size() == 40, "changed canonical road inventory")
    var market: Dictionary = {}
    var collector: Dictionary = {}
    var curved: Dictionary = {}
    for road in roads:
        if str(road.get("road_type", "")) == "market":
            market = road
        elif str(road.get("road_type", "")) == "collector":
            collector = road
        if bool(road.get("organic_pilot", false)):
            curved = road
    _check(not market.is_empty() and not collector.is_empty(),
        "actual network road classes unavailable")
    _check(not curved.is_empty(), "sampled western S bend missing")
    if not market.is_empty() and not collector.is_empty():
        _check(Style.road_rank(market) > Style.road_rank(collector),
            "market streets are not visually prioritized")
        _check(Style.road_width(market, 1.0, false) >
            Style.road_width(collector, 1.0, false),
            "full map market roads not visually distinct")
        _check(Style.road_width(market, 1.0, true) >
            Style.road_width(collector, 1.0, true),
            "minimap market roads not visually distinct")
        _check(Style.road_color(market) != Style.road_color(collector),
            "road classes use identical colors")
        _check(Style.road_width(market, 500.0, true) <= 19.0,
            "mobile minimap stroke budget exceeded")
        _check(Style.road_width(market, 500.0, false) <= 32.0,
            "zoomed full map stroke budget exceeded")
    if not curved.is_empty():
        _check((curved["centerline"] as PackedVector3Array) == Organic.centerline(),
            "style changes substituted a straight road for physical geometry")

    var bounds := Rect2(10, 20, 200, 200)
    _check(Style.segment_visible(Vector2(0, 100), Vector2(100, 100), bounds),
        "clipping dropped a visible road crossing the viewport")
    _check(not Style.segment_visible(Vector2(-100, -100),
        Vector2(-50, -50), bounds),
        "offscreen road not culled")
    var straight := Style.player_triangle(Vector2(50, 50), Vector2.UP, 10.0)
    var right := Style.player_triangle(Vector2(50, 50), Vector2.RIGHT, 10.0)
    _check(straight.size() == 3 and straight[0].y < 50.0,
        "minimap player arrow does not face screen-up")
    _check(right.size() == 3 and right[0].x > 50.0,
        "world map player arrow does not follow heading")
    _check(Map.minimap_project(Vector3(4, 0, -10), Vector3.ZERO,
        Vector3.FORWARD, bounds).distance_to(bounds.get_center()) > 0.1,
        "minimap lost its player-relative world projection")

    var ui: CivicCityMap = Map.new() as CivicCityMap
    root.add_child(ui)
    await process_frame
    _check(ui.small_frame != null and ui.map_surface != null and
        ui.small_frame.visible, "styled minimap missing at startup")
    _check(ui.small_frame.get_theme_stylebox("panel") is StyleBoxFlat,
        "dark minimap frame style not installed")
    ui.set_expanded(true)
    _check(ui.large_frame.visible and not ui.small_frame.visible and
        ui.large_frame.get_theme_stylebox("panel") is StyleBoxFlat,
        "styled full-screen map transition broken")
    ui.zoom_at(1.25)
    _check(ui.map_zoom > 1.0, "full map lost zoom controls")
    ui.set_expanded(false)
    _check(not ui.large_frame.visible and ui.small_frame.visible,
        "minimap did not return after closing full map")
    ui.queue_free()

    if failures == 0:
        print("CIVIC_CHAOS_MAP_002A_VISUAL_FOUNDATION_PASS")
    else:
        print("CIVIC_CHAOS_MAP_002A_VISUAL_FOUNDATION_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
