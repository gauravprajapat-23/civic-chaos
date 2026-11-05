extends SceneTree
## End-to-end braking and release checks through the fixed-step spawner.

const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Vehicle = preload("res://scripts/traffic/vehicle_agent.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var spawner: CivicTrafficSpawner = Spawner.new()
    root.add_child(spawner)
    spawner.spawn_interval_ticks = 200
    var graph: CivicRoadGraph = Builder.make_test_graph()
    if not spawner.configure(graph):
        _fail(spawner, "invalid graph")
        return
    var signals: CivicTrafficSignalController = Signals.new(100.0, 2.0, 1.0)
    var reservations: CivicIntersectionReservations = Reservations.new()
    signals.advance_fixed(103.0) # East-west green, north-south red.
    spawner.configure_intersection(signals, reservations)
    var vehicle: CivicVehicleAgent = Vehicle.new()
    spawner.add_child(vehicle)
    if not vehicle.configure(graph, PackedInt32Array([1, 4]), Profile.new()):
        _fail(spawner, "vehicle route rejected")
        return
    spawner.active_vehicles.append(vehicle)
    for tick in range(1, 161):
        spawner.advance_fixed(tick, 0.05)
        if vehicle.current_route_index != 0 or vehicle.lane_distance_m > 15.001:
            _fail(spawner, "vehicle crossed red stop line")
            return
    if vehicle.lane_distance_m < 10.0 or vehicle.speed_mps > 0.25:
        _fail(spawner, "vehicle failed to brake to red stop line")
        return
    signals.reset() # North-south green.
    var released := false
    for tick in range(161, 199):
        spawner.advance_fixed(tick, 0.05)
        if vehicle.current_route_index > 0:
            released = true
            break
    if not released:
        _fail(spawner, "vehicle did not resume on green")
        return
    spawner.free()
    print("CIVIC_CHAOS_TRAFFIC_BRAKING_PASS")
    quit(0)

func _fail(spawner: CivicTrafficSpawner, message: String) -> void:
    push_error(message)
    spawner.free()
    quit(1)
