extends SceneTree
## TRF-001: municipal responders respect downstream spillback and occupied
## junctions; clearing an obstruction restores entry without signal bypass.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Priority = preload("res://scripts/traffic/central_intersection_priority.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 333, false):
        _fail("test graph configuration failed")
        return
    var responder := _car(PackedInt32Array([1, 4]), graph.get_lane(1).length_m() - 7.0)
    var downstream := _car(PackedInt32Array([4]), Priority.OUTBOUND_QUEUE_CLEARANCE_M - 0.5)
    spawner.register_road_user(downstream)
    if spawner.municipal_service_hold_reason(responder) != "central_outbound_blocked":
        _fail("responder entered with blocked outbound lane")
        return
    if not bool(spawner.municipal_service_observation(responder).get("detected", false)):
        _fail("blocked responder has no stop-line observation")
        return
    downstream.lane_distance_m = Priority.OUTBOUND_QUEUE_CLEARANCE_M + 0.5
    if spawner.municipal_service_hold_reason(responder) != "":
        _fail("responder failed to release after outbound clearance")
        return
    downstream.route = PackedInt32Array([1, 4])
    downstream.current_route_index = 0
    downstream.lane_distance_m = graph.get_lane(1).length_m() - 3.0
    if spawner.municipal_service_hold_reason(responder) != "central_zone_occupied":
        _fail("responder ignored committed central vehicle")
        return
    spawner.unregister_road_user(downstream)
    if spawner.municipal_service_hold_reason(responder) != "":
        _fail("unregistered vehicle still blocked responder")
        return
    responder.free()
    downstream.free()
    spawner.queue_free()
    print("CIVIC_CHAOS_TRF_001_SERVICE_SPILLBACK_PASS")
    quit(0)

func _car(route: PackedInt32Array, distance: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.route = route
    car.current_route_index = 0
    car.lane_distance_m = distance
    car.active = true
    return car

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
