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

## GAME-019: one coherent background-world checkpoint covers fixed clock,
## signal phase, traffic demand/cars, crossing permissions and real walkers.
func checkpoint_state(pedestrians: Node3D) -> Dictionary:
    if simulation == null or traffic_signals == null or traffic_spawner == null or intersection_reservations == null or pedestrians == null:
        return {}
    if not pedestrians.has_method("checkpoint_state"):
        return {}
    return {
        "schema_version": 1,
        "clock": simulation.checkpoint_state(),
        "signals": traffic_signals.snapshot(),
        "traffic": traffic_spawner.snapshot(),
        "reservations": intersection_reservations.snapshot(),
        "pedestrians": pedestrians.call("checkpoint_state")
    }

func checkpoint_valid(raw: Variant, pedestrians: Node3D) -> bool:
    if not (raw is Dictionary) or simulation == null or traffic_signals == null or traffic_spawner == null or intersection_reservations == null or pedestrians == null:
        return false
    var data: Dictionary = raw
    if not (data.get("schema_version") is int or data.get("schema_version") is float) or float(data["schema_version"]) != 1.0:
        return false
    if not simulation.checkpoint_valid(data.get("clock")) or not traffic_signals.can_restore(data.get("signals")):
        return false
    if not traffic_spawner.can_restore(data.get("traffic")) or not intersection_reservations.can_restore(data.get("reservations")):
        return false
    if not pedestrians.has_method("checkpoint_valid") or not bool(pedestrians.call("checkpoint_valid", data.get("pedestrians"), data.get("reservations"))):
        return false
    var saved_clock: Dictionary = data["clock"]
    var saved_traffic: Dictionary = data["traffic"]
    var saved_reservations: Dictionary = data["reservations"]
    return int(saved_clock["tick_index"]) == int(saved_traffic["current_tick"]) and int(saved_clock["tick_index"]) == int(saved_reservations["current_tick"])

## GAME-020: two-phase commit. While the director/walkers are frozen,
## stage replacement traffic but RETAIN every old vehicle and counter. The
## pedestrian collision validation runs against the incoming traffic. On any
## rejection, abort the staged group; original car nodes never need rebuilding.
func restore_checkpoint(raw: Variant, pedestrians: Node3D) -> bool:
    if not checkpoint_valid(raw, pedestrians) or simulation.is_physics_processing() or pedestrians.is_physics_processing():
        return false
    var data: Dictionary = raw
    if not traffic_spawner.prepare_restore(data["traffic"]):
        return false
    # This method preflights all walker destinations before moving any body.
    # If it returns false, the previous city has not been modified.
    if not bool(pedestrians.call("restore_checkpoint", data["pedestrians"], data["reservations"])):
        traffic_spawner.abort_restore()
        return false
    # No fallible operations remain after actor placement validation.
    # Values below were validated in checkpoint_valid before staging.
    traffic_spawner.commit_restore()
    intersection_reservations.restore(data["reservations"])
    traffic_signals.restore(data["signals"])
    simulation.restore_checkpoint(data["clock"])
    return true
