extends Node3D
## Four-way test junction with one deterministic lane-following demo vehicle.

const Builder = preload("res://scripts/world/junction_builder.gd")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Director = preload("res://scripts/core/simulation_director.gd")

var road_graph: CivicRoadGraph
var demo_vehicle: CivicVehicleAgent
var simulation: SimulationDirector

func _ready() -> void:
    road_graph = Builder.make_test_graph()
    Builder.make_road_visuals(self)
    var errors := road_graph.validate()
    if not errors.is_empty():
        push_error("Junction graph invalid: %s" % str(errors))
        return
    demo_vehicle = VehicleScene.instantiate() as CivicVehicleAgent
    add_child(demo_vehicle)
    if not demo_vehicle.configure(road_graph, PackedInt32Array([1, 4]), Profile.new()):
        push_error("Could not configure demo vehicle")
        return
    simulation = Director.new()
    add_child(simulation)
    simulation.register_system(_on_simulation_tick)

func _on_simulation_tick(_tick_index: int, fixed_delta: float) -> void:
    if is_instance_valid(demo_vehicle):
        demo_vehicle.advance_fixed(fixed_delta)
