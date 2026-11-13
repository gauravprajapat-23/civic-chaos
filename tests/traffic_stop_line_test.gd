extends SceneTree

const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Vehicle = preload("res://scripts/traffic/vehicle_agent.gd")

var _spawner: CivicTrafficSpawner
var _north: CivicVehicleAgent
var _east: CivicVehicleAgent

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var spawner: CivicTrafficSpawner = Spawner.new()
    _spawner = spawner
    if not spawner.configure(graph):
        _fail("spawner configuration")
        return
    var signals: CivicTrafficSignalController = Signals.new(4.0, 2.0, 1.0)
    var reservations: CivicIntersectionReservations = Reservations.new()
    spawner.configure_intersection(signals, reservations)
    var north: CivicVehicleAgent = Vehicle.new()
    _north = north
    north.route = PackedInt32Array([1, 4])
    north.lane_distance_m = 12.0
    var east: CivicVehicleAgent = Vehicle.new()
    _east = east
    east.route = PackedInt32Array([3, 2])
    east.lane_distance_m = 12.0
    var empty := {"detected": false}
    if spawner.apply_stop_line_observation(north, empty).get("detected", false):
        _fail("north green incorrectly stopped")
        return
    if not spawner.apply_stop_line_observation(east, empty).get("detected", false):
        _fail("east red did not stop")
        return
    signals.advance_fixed(7.0)
    if not spawner.apply_stop_line_observation(north, empty).get("detected", false):
        _fail("north red did not stop")
        return
    if spawner.apply_stop_line_observation(east, empty).get("detected", false):
        _fail("east green incorrectly stopped")
        return
    var pedestrian_id: int = 100001
    var zone := "pedestrian_crossing_ns"
    var granted: Dictionary = reservations.request(pedestrian_id, PackedStringArray([zone]), 0, 50)
    if not granted.get("granted", false) or not reservations.occupy(pedestrian_id, zone):
        _fail("pedestrian occupancy setup")
        return
    if not spawner.apply_stop_line_observation(east, empty).get("detected", false):
        _fail("occupied crossing did not stop green vehicle")
        return
    reservations.release(pedestrian_id, zone)
    reservations.cancel(pedestrian_id)
    if spawner.apply_stop_line_observation(east, empty).get("detected", false):
        _fail("released crossing still blocks green")
        return
    east.lane_distance_m = 15.0
    var stop_observation: Dictionary = spawner.apply_stop_line_observation(east, empty)
    if stop_observation.get("detected", false):
        _fail("green stop-line boundary blocked")
        return
    signals.advance_fixed(4.0)
    stop_observation = spawner.apply_stop_line_observation(east, empty)
    if not stop_observation.get("detected", false) or absf(float(stop_observation["gap_m"]) - east.minimum_gap_m) > 0.001:
        _fail("red stop-line boundary gap invalid")
        return
    print("CIVIC_CHAOS_TRAFFIC_STOP_LINE_PASS")
    _finish(0)

func _fail(message: String) -> void:
    push_error(message)
    _finish(1)

func _finish(exit_code: int) -> void:
    if is_instance_valid(_north):
        _north.free()
    if is_instance_valid(_east):
        _east.free()
    if is_instance_valid(_spawner):
        _spawner.free()
    quit(exit_code)
