extends SceneTree

const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Router = preload("res://scripts/traffic/lane_router.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph := Builder.make_city_graph()
    if graph.lane_count() != 80 or not graph.validate().is_empty():
        _fail("expanded graph must contain 80 valid directed lanes")
        return
    var secondary := false
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        for point in lane.centerline:
            if absf(point.x - 46.0) < 0.01 or absf(point.z + 46.0) < 0.01:
                secondary = true
    if not secondary:
        _fail("secondary streets absent from lane graph")
        return
    var router := Router.new(graph)
    var path: Dictionary = router.find_route(100, 179, 1)
    if not path["ok"]:
        _fail("expanded city lanes are not connected")
        return
    var spawner := Spawner.new()
    root.add_child(spawner)
    if not spawner.configure(graph, 1234, true):
        _fail("expanded traffic spawner rejected graph")
        return
    for attempt in range(12):
        spawner.try_spawn()
    if spawner.active_vehicles.is_empty():
        _fail("no perimeter traffic spawned")
        return
    for car in spawner.active_vehicles:
        if car.route.size() < 4:
            _fail("city route did not traverse multiple road segments")
            return
    spawner.queue_free()
    print("CIVIC_CHAOS_CITY_TRAFFIC_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
