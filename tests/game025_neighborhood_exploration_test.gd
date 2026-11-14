extends SceneTree
## GAME-025-03: visitable neighborhoods, safe scenery and real map routes.
const Zones = preload("res://scripts/world/living_city_zones.gd")
const Exploration = preload("res://scripts/world/living_city_exploration.gd")
const Map = preload("res://scripts/ui/civic_city_map.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if not Zones.valid_layout() or Zones.LOCATIONS.size() != 4:
        _fail("discovery zones overlap road axes or are incomplete")
        return
    var ids: Dictionary = {}
    for zone in Zones.all():
        var id: String = str(zone["id"])
        if ids.has(id) or Zones.by_id(id).is_empty():
            _fail("duplicate or missing neighborhood definition")
            return
        ids[id] = true
        if not Zones.nearby(zone["position"]).has(id):
            _fail("own zone cannot be discovered")
            return
    if not Zones.nearby(Vector3(0, 0, 0)).is_empty():
        _fail("central crossing incorrectly triggers a district visit")
        return

    var world := Node3D.new()
    root.add_child(world)
    var walker := Node3D.new()
    walker.position = Vector3(0, 0, 0)
    world.add_child(walker)
    var exploration := Exploration.new() as CivicLivingCityExploration
    world.add_child(exploration)
    if not exploration.configure(walker):
        _fail("exploration world failed to build")
        return
    var notices: Array[String] = []
    exploration.zone_discovered.connect(func(id: String, _title: String) -> void:
        notices.append(id)
    )
    for zone in Zones.all():
        var marker: Node3D = exploration.get_node_or_null("Zone_" + str(zone["id"])) as Node3D
        if marker == null or marker.get_node_or_null("ZoneName") == null:
            _fail("missing visible neighborhood waypoint")
            return
        for child in marker.get_children():
            if child is CollisionObject3D or child is CollisionShape3D:
                _fail("decorative neighborhood object has an unsafe collision body")
                return
        exploration.scan_position(zone["position"])
        exploration.scan_position(zone["position"])
    var visited: Dictionary = exploration.visit_state()
    if notices.size() != 4 or int(visited["count"]) != 4 or int(visited["total"]) != 4:
        _fail("locations not discovered exactly once")
        return
    if not exploration.visit_state()["visited"].has("Community Garden"):
        _fail("discoveries do not surface friendly neighborhood titles")
        return

    var map := Map.new() as CivicCityMap
    root.add_child(map)
    await process_frame
    map.set_road_graph(Builder.make_city_graph())
    map.update_position(Vector3(0, 0, -15), Vector3.FORWARD, {"has_target": false})
    for i in range(Zones.LOCATIONS.size()):
        map._select_location(Map.LANDMARKS.size() + i)
        var goal: Dictionary = map._navigation_goal()
        if not bool(goal.get("has_target", false)) or goal["target"] != Zones.LOCATIONS[i]["position"]:
            _fail("selected neighborhood map target differs from real zone")
            return
        if not bool(map.route_state.get("ok", false)):
            _fail("road graph cannot guide player to selected zone")
            return
    map._select_location(-1)
    if bool(map._navigation_goal().get("has_target", false)):
        _fail("map invented a mission after returning from exploration")
        return
    map.queue_free()
    world.queue_free()
    print("CIVIC_CHAOS_GAME025_NEIGHBORHOOD_EXPLORATION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
