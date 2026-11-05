class_name CivicTrafficSpawner
extends Node3D
## Seeded traffic demand, spawn clearance and aggregate flow metrics.

const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Budget = preload("res://scripts/traffic/traffic_budget.gd")
var work_budget: CivicTrafficBudget = Budget.new()

@export_range(1, 100, 1) var maximum_active: int = 20
@export_range(0.1, 15.0, 0.1) var spawn_clearance_m: float = 5.0
@export_range(1, 200, 1) var spawn_interval_ticks: int = 30
@export var seed: int = 12345

var road_graph: CivicRoadGraph
var traffic_signals: CivicTrafficSignalController
var crossing_reservations: CivicIntersectionReservations

func configure_intersection(signals: CivicTrafficSignalController, reservations: CivicIntersectionReservations) -> void:
    traffic_signals = signals
    crossing_reservations = reservations
var rng := RandomNumberGenerator.new()
var active_vehicles: Array[CivicVehicleAgent] = []
var spawned_total: int = 0
var completed_total: int = 0
var rejected_total: int = 0
var total_delay_seconds: float = 0.0
var current_tick: int = 0
var _vehicle_delay: Dictionary = {}

func configure(graph: CivicRoadGraph, random_seed: int = 12345) -> bool:
	if graph == null or not graph.validate().is_empty():
		return false
	for vehicle in active_vehicles:
		if is_instance_valid(vehicle):
			vehicle.queue_free()
	active_vehicles.clear()
	_vehicle_delay.clear()
	work_budget.configure(maximum_active, 8)
	road_graph = graph
	seed = random_seed
	rng.seed = seed
	spawned_total = 0
	completed_total = 0
	rejected_total = 0
	total_delay_seconds = 0.0
	current_tick = 0
	return true

func advance_fixed(tick: int, delta: float) -> void:
	if road_graph == null or tick <= current_tick or delta <= 0.0:
		return
	var started_us := Time.get_ticks_usec()
	current_tick = tick
	# Sample all followers before moving to avoid update-order sensing.
	var observations: Dictionary = {}
	for vehicle in active_vehicles:
		observations[vehicle.get_instance_id()] = CivicTrafficSensor.nearest_lead(vehicle, active_vehicles)
	for vehicle in active_vehicles:
		var observation: Dictionary = observations[vehicle.get_instance_id()]
		if observation.get("detected", false):
			vehicle.set_lead_observation(float(observation["gap_m"]), float(observation["lead_speed_mps"]))
		else:
			vehicle.clear_lead_observation()
		if vehicle.speed_mps < 0.2:
			_vehicle_delay[vehicle.get_instance_id()] = float(_vehicle_delay.get(vehicle.get_instance_id(), 0.0)) + delta
		vehicle.advance_fixed(delta)
	for index in range(active_vehicles.size() - 1, -1, -1):
		var vehicle := active_vehicles[index]
		if not vehicle.active:
			completed_total += 1
			total_delay_seconds += float(_vehicle_delay.get(vehicle.get_instance_id(), 0.0))
			_vehicle_delay.erase(vehicle.get_instance_id())
			active_vehicles.remove_at(index)
			vehicle.queue_free()
	if tick % spawn_interval_ticks == 0 and active_vehicles.size() < mini(maximum_active, work_budget.maximum_agents):
		try_spawn()
	work_budget.record_duration_us(Time.get_ticks_usec() - started_us)

func apply_stop_line_observation(vehicle: CivicVehicleAgent, initial_observation: Dictionary) -> Dictionary:
    var observation: Dictionary = initial_observation.duplicate()
    # Treat a red/amber stop line as a stationary virtual lead vehicle.
    var entry_lane: int = vehicle.route[0] if not vehicle.route.is_empty() else -1
    if traffic_signals != null and vehicle.current_route_index == 0 and entry_lane >= 0:
        var approach: String = {1: "N", 3: "E", 5: "S", 7: "W"}.get(entry_lane, "")
        var signal: String = traffic_signals.aspect_for_approach(approach)
        var lane: CivicLaneData = road_graph.get_lane(entry_lane)
        if lane != null:
            var stop_distance: float = maxf(0.0, lane.length_m() - 5.0)
            var gap: float = stop_distance - vehicle.lane_distance_m
            var pedestrian_occupied: bool = false
            if crossing_reservations != null:
                pedestrian_occupied = crossing_reservations.occupant("pedestrian_crossing_ns") >= 0 or crossing_reservations.occupant("pedestrian_crossing_ew") >= 0
            if gap >= 0.0 and (signal != "green" or pedestrian_occupied):
                var safe_gap: float = maxf(0.0, gap + vehicle.minimum_gap_m)
                if not observation.get("detected", false) or safe_gap < float(observation["gap_m"]):
                    observation = {"detected": true, "gap_m": safe_gap, "lead_speed_mps": 0.0}
    return observation

func try_spawn() -> bool:
	if road_graph == null or active_vehicles.size() >= mini(maximum_active, work_budget.maximum_agents):
		return false
	var entry_lanes := PackedInt32Array([1, 3, 5, 7])
	var entry: int = entry_lanes[rng.randi_range(0, entry_lanes.size() - 1)]
	var exits: Array[int] = road_graph.outgoing_legal_lanes(entry, 1)
	if exits.is_empty():
		rejected_total += 1
		return false
	for vehicle in active_vehicles:
		if vehicle.active and vehicle.route[vehicle.current_route_index] == entry and vehicle.lane_distance_m < spawn_clearance_m:
			rejected_total += 1
			return false
	var destination: int = exits[rng.randi_range(0, exits.size() - 1)]
	var vehicle := VehicleScene.instantiate() as CivicVehicleAgent
	if vehicle == null:
		push_error("Vehicle scene did not instantiate as CivicVehicleAgent")
		rejected_total += 1
		return false
	add_child(vehicle)
	if not vehicle.configure(road_graph, PackedInt32Array([entry, destination]), Profile.new()):
		vehicle.queue_free()
		rejected_total += 1
		return false
	active_vehicles.append(vehicle)
	spawned_total += 1
	return true

func metrics() -> Dictionary:
	var queue_count := 0
	for vehicle in active_vehicles:
		if vehicle.speed_mps < 0.2:
			queue_count += 1
	return {
		"active": active_vehicles.size(),
		"timing": work_budget.metrics(),
		"queue": queue_count,
		"spawned": spawned_total,
		"completed": completed_total,
		"rejected": rejected_total,
		"delay_seconds": total_delay_seconds,
		"throughput_per_minute": float(completed_total) * 60.0 / maxf(float(current_tick) / 20.0, 0.05)
	}
