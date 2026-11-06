extends Node3D
## Four-way test junction with one deterministic lane-following demo vehicle.

const Builder = preload("res://scripts/world/junction_builder.gd")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Director = preload("res://scripts/core/simulation_director.gd")
const SignalController = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

var road_graph: CivicRoadGraph
var demo_vehicle: CivicVehicleAgent
var simulation: SimulationDirector
var traffic_signals: CivicTrafficSignalController
var intersection_reservations: CivicIntersectionReservations
var traffic_spawner: CivicTrafficSpawner

func _ready() -> void:
    var expanded_city: bool = get_parent() != null and get_parent().get_node_or_null("Neighborhood") != null
    road_graph = Builder.make_city_graph() if expanded_city else Builder.make_test_graph()
    # The playable district already owns the road surface. Avoid overlapping meshes.
    if get_parent() == null or get_parent().get_node_or_null("Neighborhood") == null:
        Builder.make_road_visuals(self)
    var errors := road_graph.validate()
    if not errors.is_empty():
        push_error("Junction graph invalid: %s" % str(errors))
        return
    traffic_spawner = Spawner.new()
    add_child(traffic_spawner)
    if not traffic_spawner.configure(road_graph, 12345, expanded_city):
        push_error("Could not initialize traffic spawner")
        return
    traffic_signals = SignalController.new()
    intersection_reservations = Reservations.new()
    traffic_spawner.configure_intersection(traffic_signals, intersection_reservations)
    simulation = Director.new()
    add_child(simulation)
    simulation.register_system(_on_simulation_tick)

func _on_simulation_tick(_tick_index: int, fixed_delta: float) -> void:
    traffic_signals.advance_fixed(fixed_delta)
    intersection_reservations.advance_to(_tick_index)
    if is_instance_valid(traffic_spawner):
        traffic_spawner.advance_fixed(_tick_index, fixed_delta)
