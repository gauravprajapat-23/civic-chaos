extends SceneTree

const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Vehicle = preload("res://scripts/traffic/vehicle_agent.gd")

func _initialize() -> void:
    call_deferred("_run")

func _lane(id: int, points: PackedVector3Array) -> CivicLaneData:
    var lane := Lane.new()
    lane.lane_id = id
    lane.centerline = points
    return lane

func _run() -> void:
    var graph := Graph.new()
    var first := _lane(1, PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0)]))
    var second := _lane(2, PackedVector3Array([Vector3(10, 0, 0), Vector3(10, 0, 10)]))
    first.next_lane_ids = PackedInt32Array([2])
    graph.add_lane(first)
    graph.add_lane(second)
    var profile := Profile.new()
    profile.maximum_speed_mps = 5.0
    var car := Vehicle.new()
    root.add_child(car)
    if not car.configure(graph, PackedInt32Array([1, 2]), profile):
        _fail("valid route rejected")
        return
    var max_speed := 0.0
    var saw_turn := false
    for tick in range(400):
        car.advance_fixed(0.05)
        max_speed = maxf(max_speed, car.speed_mps)
        if car.current_route_index == 1:
            saw_turn = true
        if not car.active:
            break
    if car.active or not saw_turn or car.global_position.distance_to(Vector3(10, 0, 10)) > 0.02:
        _fail("vehicle failed to complete turn")
        return
    if max_speed > 5.001:
        _fail("speed limit exceeded")
        return
    if not car.configure(graph, PackedInt32Array([1]), profile):
        _fail("straight route rejected")
        return
    for tick in range(10):
        car.advance_fixed(0.05)
    car.stop_requested = true
    for tick in range(100):
        car.advance_fixed(0.05)
    if car.speed_mps > 0.01 or car.lane_distance_m >= 10.0:
        _fail("braking failed")
        return
    if car.configure(graph, PackedInt32Array([2, 1]), profile):
        _fail("disconnected route accepted")
        return
    var curve := PackedVector3Array([Vector3.ZERO, Vector3(5, 0, 0), Vector3(5, 0, 5)])
    var sample: Dictionary = Vehicle.sample_centerline(curve, 7.0)
    if sample["position"].distance_to(Vector3(5, 0, 2)) > 0.001:
        _fail("curved polyline sample incorrect")
        return
    car.queue_free()
    print("CIVIC_CHAOS_VEHICLE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
