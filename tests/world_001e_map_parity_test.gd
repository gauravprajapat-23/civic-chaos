extends SceneTree
## WORLD-001E: the mini and full city map must draw actual world roads,
## including the sampled western curve, not a separate five-axis grid.
const Map = preload("res://scripts/ui/civic_city_map.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
const Geometry = preload("res://scripts/world/organic_road_geometry.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
var failures: int = 0

func _check(ok: bool, why: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-001E: " + why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var code: String = FileAccess.get_file_as_string(
        "res://scripts/ui/civic_city_map.gd")
    _check(code.count("for road in CityNetwork.roads():") >= 2,
        "mini and full map are not both drawing the canonical city graph")
    _check(not code.contains("for coordinate in RoadLayout.coordinates():"),
        "stale grid road rendering still active")
    var roads: Array[Dictionary] = Network.roads()
    var road_count: int = 0
    var pilot: Dictionary = {}
    for edge in roads:
        if bool(edge.get("vehicle_access", false)):
            road_count += 1
        if bool(edge.get("organic_pilot", false)):
            pilot = edge
    _check(road_count == 40, "network road inventory changed")
    var points: PackedVector3Array = pilot.get("centerline", PackedVector3Array())
    _check(points == Geometry.centerline(), "map curve differs from 3D asphalt")
    _check(points.size() >= 20 and points[0] == Geometry.PILOT_FROM and
        points[points.size() - 1] == Geometry.PILOT_TO,
        "map curve endpoints/segments invalid")
    var graph: CivicRoadGraph = Builder.make_city_graph()
    for lane_id in [102, 103]:
        var lane: CivicLaneData = graph.get_lane(lane_id)
        _check(lane != null, "missing drivable curved street")
        if lane == null:
            continue
        for point in lane.centerline:
            var closest: float = INF
            for road_point in points:
                closest = minf(closest, point.distance_to(road_point))
            _check(closest <= 1.75, "vehicle lane diverged from drawn street")
    var world_area := Rect2(0, 0, 320, 320)
    var a: Vector2 = Map.world_to_map(points[0], world_area)
    var mid: Vector2 = Map.world_to_map(points[int(points.size() / 2)], world_area)
    var b: Vector2 = Map.world_to_map(points[points.size() - 1], world_area)
    _check(mid.x > a.x + 1.0 and mid.x > b.x + 1.0,
        "curved road collapses into an old straight map axis")
    var live: CivicCityMap = Map.new() as CivicCityMap
    root.add_child(live)
    await process_frame
    live.set_road_graph(graph)
    live.update_position(Vector3(-110, 0, -83), Vector3.FORWARD, {})
    live.set_expanded(true)
    live.zoom_at(1.25)
    live.recenter_on_player()
    _check(live.map_zoom > 1.0 and live.map_center.x < 0.0,
        "full map pan/zoom no longer follows live player")
    live.set_expanded(false)
    _check(live.selected_location == -1,
        "reflow unexpectedly changed active waypoint")
    live.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_001E_MAP_PARITY_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_001E_MAP_PARITY_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
