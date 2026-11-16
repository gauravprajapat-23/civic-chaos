extends SceneTree
## TRAFFIC-FIX-08: new background routes detour around an active civic
## incident; existing traffic and physical offender remain present.
## The detour disappears on legitimate incident recovery or scene rebuild.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 4391, true):
        _fail("city traffic could not configure")
        return
    var restricted_id: int = -1
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if lane.centerline[0].distance_to(Vector3(-46, 0, 0)) < 0.1 and lane.centerline[-1].distance_to(Vector3.ZERO) < 0.1:
            restricted_id = id
            break
    if restricted_id < 0 or not spawner.set_incident_route_closure("wrong_way", restricted_id):
        _fail("cannot close live Wrong Way approach lane")
        return
    if spawner.set_incident_route_closure("", restricted_id) or spawner.set_incident_route_closure("broken", -12):
        _fail("invalid closure was accepted")
        return
    if not spawner.route_lane_closed(restricted_id):
        _fail("closed incident route remains open")
        return
    if spawner._open_route_options([restricted_id]).size() != 0:
        _fail("route planner still advertises blocked civic lane")
        return
    var valid_routes: int = 0
    spawner.maximum_active = 18
    for step in range(120):
        await physics_frame
        if spawner.try_spawn():
            valid_routes += 1
        for car in spawner.active_vehicles:
            if car.route.has(restricted_id):
                _fail("new background car was routed through the live incident")
                return
        if valid_routes >= 10:
            break
    if valid_routes == 0:
        _fail("closing one lane blocked every alternative city entry")
        return
    var retained: CivicVehicleAgent = spawner.active_vehicles[0]
    var prior_route: PackedInt32Array = retained.route.duplicate()
    spawner.clear_incident_route_closure("wrong_way")
    if spawner.route_lane_closed(restricted_id):
        _fail("authorized recovery did not reopen the road")
        return
    if retained.route != prior_route or not retained.active:
        _fail("detouring new cars modified or despawned existing traffic")
        return
    if not spawner.set_incident_route_closure("wrong_way", restricted_id):
        _fail("could not reactivate incident closure")
        return
    if not spawner.configure(graph, 4391, true):
        _fail("configured road rebuild failed")
        return
    if spawner.route_lane_closed(restricted_id):
        _fail("ephemeral incident closure leaked through new scene generation")
        return
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_08_INCIDENT_DETOUR_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
