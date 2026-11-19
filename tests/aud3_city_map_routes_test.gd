extends SceneTree
## AUD3-MAP-02: shortest street guidance must use actual junction network.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Routes = preload("res://scripts/ui/civic_map_routes.gd")
const Map = preload("res://scripts/ui/civic_city_map.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    if not graph.validate().is_empty():
        _fail("real city graph invalid")
        return
    var origin := Vector3(-120, 0, -120)
    var target := Vector3(120, 0, 120)
    var route: Dictionary = Routes.plan(graph, origin, target)
    if not bool(route.get("ok", false)):
        _fail("opposite city corners could not route")
        return
    var points: PackedVector3Array = route["points"]
    if points.size() < 3 or points[0] != origin or points[points.size() - 1] != target:
        _fail("route did not reach both real corners")
        return
    if float(route["distance_m"]) < 470.0 or float(route["distance_m"]) > 520.0:
        _fail("route did not follow street grid distances")
        return
    var replay: Dictionary = Routes.plan(graph, origin, target)
    if points != replay["points"] or float(route["distance_m"]) != float(replay["distance_m"]):
        _fail("routing not deterministic")
        return
    if bool(Routes.plan(null, origin, target).get("ok", false)):
        _fail("missing graph produced fabricated route")
        return
    var ui: CivicCityMap = Map.new() as CivicCityMap
    root.add_child(ui)
    await process_frame
    ui.set_road_graph(graph)
    ui.update_position(Vector3(-46, 0, 0), Vector3.FORWARD,
        {"title": "Wrong Way", "objective": "Find the post",
        "has_target": true, "target": Vector3(-20, 0, -5.3)})
    if not bool(ui.route_state.get("ok", false)) or not ui.navigation_label.text.contains("Road route"):
        _fail("live mission route/distance missing")
        return
    ui._select_location(0)
    if ui.selected_location != 0 or ui._navigation_goal()["title"] != "Market Chowk":
        _fail("landmark selection did not switch destination")
        return
    ui._select_location(-1)
    if ui._navigation_goal()["title"] != "Wrong Way":
        _fail("return to active mission failed")
        return
    ui.update_position(Vector3.ZERO, Vector3.FORWARD, {"has_target": false})
    if not ui.route_state.is_empty() or not ui.navigation_label.text.contains("No location selected"):
        _fail("mission with no waypoint invented navigation")
        return
    ui.queue_free()
    print("CIVIC_CHAOS_AUD3_CITY_MAP_ROUTES_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
