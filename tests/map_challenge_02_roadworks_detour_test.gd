extends SceneTree
## MAP-CHALLENGE-02 — real temporary road closure and legal alternate
## routes, without ever altering an existing car, physical road, or
## awarding a fake reputation receipt for uncompleted traffic.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Works = preload("res://scripts/world/roadworks_detour.gd")
const Router = preload("res://scripts/traffic/lane_router.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    if not graph.validate().is_empty():
        _fail("new city graph invalid")
        return
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 2468, true):
        _fail("spawner refused city graph")
        return
    var works := Works.new() as CivicRoadworksDetour
    root.add_child(works)
    if not works.configure(spawner):
        _fail("roadworks controller not configured")
        return
    if works.active():
        _fail("roadworks illegally started before interval")
        return
    var original_id: int = works._find_lane(Works.CANDIDATE_STARTS[0], Works.CANDIDATE_ENDS[0])
    if original_id < 0 or not works._has_detour(original_id):
        _fail("outer road cannot support a genuine legal detour")
        return
    var existing := CivicVehicleAgent.new()
    existing.active = true
    existing.route = PackedInt32Array([original_id])
    spawner.register_road_user(existing)
    works.advance_to(Works.FIRST_TICK)
    if works.active() and works.lane_id == original_id:
        _fail("roadworks closed a lane already in a real car route")
        return
    spawner.unregister_road_user(existing)
    existing.free()
    works.advance_to(Works.FIRST_TICK + 200)
    if not works.active():
        _fail("roadworks could not activate on a truly empty legal segment")
        return
    var blocked_id: int = works.lane_id
    var blocked_choices: Array[int] = [blocked_id]
    if not spawner.route_lane_closed(blocked_id) or (
            spawner._open_route_options(blocked_choices).size() != 0):
        _fail("new traffic routes still use closed road")
        return
    for car in spawner.active_vehicles:
        if car.route.has(blocked_id):
            _fail("preexisting live route was altered by closure")
            return
    var warning: Node3D = works.get_node_or_null("RoadworksWarning")
    if warning == null or warning.get_child_count() < 2:
        _fail("visible roadworks warning posts missing")
        return
    for marker in warning.get_children():
        if marker is CollisionObject3D or marker is CollisionShape3D:
            _fail("dynamic roadworks introduced a physical road blockage")
            return
    if bool(works.request_player_reopen().get("accepted", false)):
        _fail("marshal reopened without any real journey completion")
        return
    spawner.completed_total += 1
    if bool(works.request_player_reopen().get("accepted", false)):
        _fail("marshal accepted only one actual completed traffic journey")
        return
    spawner.completed_total += 1
    if not bool(works.request_player_reopen().get("accepted", false)):
        _fail("verified player intervention could not reopen road")
        return
    if works.active() or spawner.route_lane_closed(blocked_id):
        _fail("marshal did not restore actual route availability")
        return
    var old_count: int = spawner.completed_total
    works.advance_to(works.next_event_tick)
    if not works.active():
        _fail("roadworks did not recur in a later safe window")
        return
    var next_lane: int = works.lane_id
    works.advance_to(works.finish_tick)
    if works.active() or spawner.route_lane_closed(next_lane):
        _fail("timed closure failed to reopen automatically")
        return
    if spawner.completed_total != old_count:
        _fail("event invented completed background vehicle journeys")
        return
    works.queue_free()
    spawner.queue_free()
    print("CIVIC_CHAOS_MAP_CHALLENGE_02_ROADWORKS_DETOUR_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
