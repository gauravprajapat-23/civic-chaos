class_name CivicTrafficSpawner
extends Node3D
## Seeded traffic demand, spawn clearance and aggregate flow metrics.

const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Budget = preload("res://scripts/traffic/traffic_budget.gd")
const OuterPriority = preload("res://scripts/traffic/outer_intersection_priority.gd")
var work_budget: CivicTrafficBudget = Budget.new()

@export_range(1, 100, 1) var maximum_active: int = 20
@export_range(0.1, 15.0, 0.1) var spawn_clearance_m: float = 5.0
@export_range(1, 200, 1) var spawn_interval_ticks: int = 30
@export var seed: int = 12345

var road_graph: CivicRoadGraph
var city_mode: bool = false
var city_entry_lanes: PackedInt32Array = PackedInt32Array()
var normal_entry_lanes: PackedInt32Array = PackedInt32Array()
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

func configure(graph: CivicRoadGraph, random_seed: int = 12345, expanded_city: bool = false) -> bool:
	# Preflight *all* fallible inputs before touching the current traffic
	# generation or an in-progress checkpoint transaction. A rejected city
	# graph must never destroy the existing fleet or lose its RNG/counters.
	if graph == null or not graph.validate().is_empty():
		return false
	if maximum_active < 1 or spawn_interval_ticks < 1 or not is_finite(spawn_clearance_m) or spawn_clearance_m <= 0.0:
		return false
	var proposed_entry_lanes := PackedInt32Array()
	var proposed_normal_lanes := PackedInt32Array()
	if expanded_city:
		for lane_id in graph.sorted_lane_ids():
			var lane: CivicLaneData = graph.get_lane(lane_id)
			var origin: Vector3 = lane.centerline[0]
			if (absf(origin.x) >= 119.0 or absf(origin.z) >= 119.0) and lane.centerline[1].length_squared() < origin.length_squared() and lane.is_vehicle_allowed(1) and not lane.is_wrong_way_connector and not graph.outgoing_legal_lanes(lane_id, 1).is_empty():
				proposed_entry_lanes.append(lane_id)
	else:
		# A graph may validate geometrically without the legacy 1/3/5/7
		# entrances. Never "succeed" with a fleet that cannot spawn a route.
		for lane_id in [1, 3, 5, 7]:
			var lane: CivicLaneData = graph.get_lane(lane_id)
			if lane != null and not lane.is_wrong_way_connector and lane.is_vehicle_allowed(1) and not graph.outgoing_legal_lanes(lane_id, 1).is_empty():
				proposed_normal_lanes.append(lane_id)
	if proposed_entry_lanes.is_empty() and proposed_normal_lanes.is_empty():
		return false
	# All validation succeeded. Now replace the old generation atomically
	# with respect to configuration failure (and intentionally abort a
	# previously prepared checkpoint for a successful reconfiguration).
	if restore_prepared():
		abort_restore()
	for vehicle in active_vehicles:
		if is_instance_valid(vehicle):
			vehicle.queue_free()
	active_vehicles.clear()
	_vehicle_delay.clear()
	work_budget.configure(maximum_active, 8)
	work_budget.reset_runtime()
	road_graph = graph
	city_mode = expanded_city
	city_entry_lanes = proposed_entry_lanes
	normal_entry_lanes = proposed_normal_lanes
	seed = random_seed
	rng.seed = seed
	spawned_total = 0
	completed_total = 0
	rejected_total = 0
	total_delay_seconds = 0.0
	current_tick = 0
	return true

func advance_fixed(tick: int, delta: float) -> void:
	# No traffic tick may advance between PREPARE and either COMMIT or ABORT,
	# even when a test harness invokes this directly without the director.
	if restore_prepared() or road_graph == null or tick <= current_tick or delta <= 0.0 or not is_finite(delta) or spawn_interval_ticks < 1:
		return
	var started_us := Time.get_ticks_usec()
	current_tick = tick
	# Freeze both following and junction decisions before any vehicle moves.
	# Otherwise an earlier fleet slot can enter a conflict zone while a later
	# slot arbitrates against already-mutated positions in the same fixed tick.
	var observations: Dictionary = {}
	for vehicle in active_vehicles:
		var observation: Dictionary = CivicTrafficSensor.nearest_lead(vehicle, active_vehicles)
		observations[vehicle.get_instance_id()] = apply_stop_line_observation(vehicle, observation)
	# Capture actual evaluations; do not throttle or reuse stale lead
	# observations just to report lower CPU cost.
	work_budget.record_sensor_checks(observations.size())
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
	# The central junction keeps its original signal + crossing reservation
	# contract. Outer junctions use a fixed-tick stateless priority policy,
	# independent of the one central signal and safe across F5/F9 restores.
	if road_graph == null or vehicle == null or vehicle.route.is_empty():
		return observation
	if not city_mode and vehicle.current_route_index != 0:
		return observation
	if vehicle.current_route_index < 0 or vehicle.current_route_index >= vehicle.route.size():
		return observation
	var lane: CivicLaneData = road_graph.get_lane(vehicle.route[vehicle.current_route_index])
	if lane == null:
		return observation
	var stop_distance: float = maxf(0.0, lane.length_m() - 5.0)
	var gap: float = stop_distance - vehicle.lane_distance_m
	if city_mode and OuterPriority.is_controlled(lane):
		var decision: Dictionary = OuterPriority.disposition(vehicle, road_graph, active_vehicles, current_tick)
		var must_yield: bool = bool(decision.get("yield", false))
		# A pedestrian in the road's crossing conflict zone receives the
		# same priority. Check only when the approaching car can enter soon;
		# cars already past the stopline must clear instead of freezing.
		if not must_yield and gap >= 0.0 and gap <= 12.0:
			must_yield = _outer_pedestrian_occupied(OuterPriority.junction_for_lane(lane))
		if must_yield and gap >= 0.0:
			return _merge_stop_line(observation, gap, vehicle.minimum_gap_m)
		return observation
	if traffic_signals == null:
		return observation
	var approach: String = signal_approach_for_lane(lane, city_mode)
	if approach.is_empty():
		return observation
	var pedestrian_occupied: bool = false
	if crossing_reservations != null:
		pedestrian_occupied = crossing_reservations.occupant("pedestrian_crossing_ns") >= 0 or crossing_reservations.occupant("pedestrian_crossing_ew") >= 0
	if gap >= 0.0 and (traffic_signals.aspect_for_approach(approach) != "green" or pedestrian_occupied):
		return _merge_stop_line(observation, gap, vehicle.minimum_gap_m)
	return observation

static func _merge_stop_line(observation: Dictionary, gap: float, minimum_gap: float) -> Dictionary:
	var safe_gap: float = maxf(0.0, gap + minimum_gap)
	if not observation.get("detected", false) or safe_gap < float(observation.get("gap_m", INF)):
		return {"detected": true, "gap_m": safe_gap, "lead_speed_mps": 0.0}
	return observation

func _outer_pedestrian_occupied(junction: Vector3) -> bool:
	# The actual pedestrian collider uses collision layer 8. A small central
	# probe avoids permanent blockage by pedestrians waiting on sidewalks.
	# Pure junction policy and headless unit tests do not need this query.
	if not is_inside_tree():
		return false
	var probe := SphereShape3D.new()
	probe.radius = 2.75
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, junction + Vector3.UP * 0.85)
	query.collision_mask = 8
	query.collide_with_bodies = true
	return not get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()

## A single signal controller currently represents the center junction.
## Derive direction from geometry, never from numeric lane IDs.
static func signal_approach_for_lane(lane: CivicLaneData, expanded_city: bool) -> String:
	if lane == null or lane.centerline.size() < 2:
		return ""
	var origin: Vector3 = lane.centerline[0]
	var finish: Vector3 = lane.centerline[lane.centerline.size() - 1]
	if expanded_city and Vector2(finish.x, finish.z).length() > 3.0:
		return ""
	var heading: Vector3 = finish - origin
	if absf(heading.z) >= absf(heading.x):
		return "N" if heading.z > 0.0 else "S"
	return "W" if heading.x > 0.0 else "E"

func try_spawn() -> bool:
	if road_graph == null or active_vehicles.size() >= mini(maximum_active, work_budget.maximum_agents):
		return false
	var entry_lanes := city_entry_lanes if city_mode else normal_entry_lanes
	if entry_lanes.is_empty():
		return false
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
	var path := PackedInt32Array([entry, destination])
	if city_mode:
		for step in range(rng.randi_range(2, 5)):
			var choices: Array[int] = road_graph.outgoing_legal_lanes(path[path.size() - 1], 1)
			if choices.is_empty():
				break
			path.append(choices[rng.randi_range(0, choices.size() - 1)])
	var vehicle := VehicleScene.instantiate() as CivicVehicleAgent
	if vehicle == null:
		push_error("Vehicle scene did not instantiate as CivicVehicleAgent")
		rejected_total += 1
		return false
	add_child(vehicle)
	if not vehicle.configure(road_graph, path, Profile.new()):
		vehicle.queue_free()
		rejected_total += 1
		return false
	vehicle.physics_obstacle_checks_enabled = city_mode
	if _spawn_occupied(vehicle):
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

func _spawn_occupied(candidate: CivicVehicleAgent) -> bool:
	# Validate full oriented collider volume: player, pedestrians, cars, props.
	# Vehicle footprint helper ignores supporting road/terrain floor surfaces.
	if candidate.footprint_blocked_at(candidate.global_transform):
		return true
	for other in active_vehicles:
		if not is_instance_valid(other) or not other.active:
			continue
		var offset: Vector3 = other.global_position - candidate.global_position
		offset.y = 0.0
		if offset.length_squared() < spawn_clearance_m * spawn_clearance_m:
			return true
	return false

## GAME-019: background vehicles are ordered by snapshot slot, never
## runtime ObjectDB IDs. RNG state is decimal text because JSON's float
## numbers cannot round-trip every signed 64-bit RNG state.
func snapshot() -> Dictionary:
	var cars: Array[Dictionary] = []
	for car in active_vehicles:
		if not is_instance_valid(car) or not car.active or car.profile == null:
			continue
		var route_ids: Array[int] = []
		for lane_id in car.route:
			route_ids.append(lane_id)
		cars.append({
			"route": route_ids,
			"route_index": car.current_route_index,
			"lane_distance": car.lane_distance_m,
			"speed": car.speed_mps,
			"target_speed": car.target_speed_mps,
			"stop_requested": car.stop_requested,
			"obstacle_checks": car.physics_obstacle_checks_enabled,
			"delay": float(_vehicle_delay.get(car.get_instance_id(), 0.0)),
			"profile": {
				"max_speed": car.profile.maximum_speed_mps,
				"acceleration": car.profile.acceleration_mps2,
				"braking": car.profile.braking_mps2,
				"turn_rate": car.profile.turn_rate_radians,
				"vehicle_mask": car.profile.vehicle_mask
			}
		})
	return {
		"schema_version": 1,
		"seed": seed,
		"city_mode": city_mode,
		"current_tick": current_tick,
		"rng_state": str(rng.state),
		"spawned_total": spawned_total,
		"completed_total": completed_total,
		"rejected_total": rejected_total,
		"total_delay_seconds": total_delay_seconds,
		"cars": cars
	}

static func _finite_number(value: Variant, minimum: float, maximum: float) -> bool:
	if not (value is float or value is int):
		return false
	var number: float = float(value)
	return is_finite(number) and number >= minimum and number <= maximum

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not _finite_number(value, float(minimum), float(maximum)):
		return false
	return float(value) == floorf(float(value))

## Never stage a vehicle or overwrite traffic counters before preflight.
func can_restore(data: Variant) -> bool:
	if not (data is Dictionary) or road_graph == null:
		return false
	if not _whole(data.get("schema_version"), 1, 1):
		return false
	if not _whole(data.get("seed"), -1000000000, 1000000000) or int(data["seed"]) != seed:
		return false
	if not (data.get("city_mode") is bool) or bool(data["city_mode"]) != city_mode:
		return false
	for name in ["current_tick", "spawned_total", "completed_total", "rejected_total"]:
		if not _whole(data.get(name), 0, 1000000000):
			return false
	if int(data["completed_total"]) > int(data["spawned_total"]):
		return false
	if not _finite_number(data.get("total_delay_seconds"), 0.0, 1000000000.0):
		return false
	if not (data.get("rng_state") is String):
		return false
	var state_string: String = data["rng_state"]
	if not state_string.is_valid_int() or str(int(state_string)) != state_string:
		return false
	if not (data.get("cars") is Array) or data["cars"].size() > mini(maximum_active, work_budget.maximum_agents):
		return false
	# Every still-active car was spawned but has not yet completed.
	# Reject impossible generations before allocating replacement physics bodies.
	if int(data["completed_total"]) + data["cars"].size() > int(data["spawned_total"]):
		return false
	for item in data["cars"]:
		if not (item is Dictionary):
			return false
		if not (item.get("route") is Array):
			return false
		var saved_route: Array = item["route"]
		if saved_route.size() < 2 or saved_route.size() > 8:
			return false
		if not _whole(item.get("route_index"), 0, saved_route.size() - 1):
			return false
		if not (item.get("profile") is Dictionary):
			return false
		var parameters: Dictionary = item["profile"]
		for param in ["max_speed", "acceleration", "braking", "turn_rate"]:
			if not _finite_number(parameters.get(param), 0.01, 60.0):
				return false
		if not _whole(parameters.get("vehicle_mask"), 1, 255):
			return false
		if not (item.get("stop_requested") is bool) or not (item.get("obstacle_checks") is bool):
			return false
		for velocity_key in ["speed", "target_speed"]:
			if not _finite_number(item.get(velocity_key), 0.0, float(parameters["max_speed"]) + 0.01):
				return false
		if not _finite_number(item.get("delay"), 0.0, 1000000000.0):
			return false
		var lanes: PackedInt32Array = PackedInt32Array()
		for lane_variant in saved_route:
			if not _whole(lane_variant, 0, 1000000):
				return false
			var lane_id: int = int(lane_variant)
			var lane: CivicLaneData = road_graph.get_lane(lane_id)
			if lane == null or lane.is_wrong_way_connector or not lane.is_vehicle_allowed(int(parameters["vehicle_mask"])):
				return false
			if not lanes.is_empty() and not road_graph.outgoing_legal_lanes(lanes[lanes.size() - 1], int(parameters["vehicle_mask"])).has(lane_id):
				return false
			lanes.append(lane_id)
		var current_lane: CivicLaneData = road_graph.get_lane(lanes[int(item["route_index"])])
		if not _finite_number(item.get("lane_distance"), 0.0, current_lane.length_m() + 0.025):
			return false
		# A saved *active* car already at its final endpoint can never
		# complete: advance_fixed() computes zero desired speed and the
		# _travel() completion path is not reached. Refuse that ghost car.
		if int(item["route_index"]) == saved_route.size() - 1 and float(item["lane_distance"]) >= current_lane.length_m() - 0.000001:
			return false
	return true

## GAME-020: a prepared car generation does NOT delete the running traffic.
## Keep old actors/route counters intact until the pedestrian landing places
## have passed all collision probes. Commit is deliberately infallible after
## preflight; abort recovers the original physical actors and collision layers.
var _prepared_restore: Dictionary = {}

func restore_prepared() -> bool:
	return not _prepared_restore.is_empty()

func prepare_restore(data: Variant) -> bool:
	if restore_prepared() or not can_restore(data):
		return false
	var disabled: Array[Dictionary] = []
	for old in active_vehicles:
		if not is_instance_valid(old):
			continue
		var body := old.get_node_or_null("CollisionBody") as StaticBody3D
		if body != null:
			disabled.append({"body": body, "layer": body.collision_layer})
			body.collision_layer = 0
	var staged: Array[CivicVehicleAgent] = []
	var staged_delay: Dictionary = {}
	var valid: bool = true
	for item in data["cars"]:
		var parameters: Dictionary = item["profile"]
		var vehicle_profile := Profile.new()
		vehicle_profile.maximum_speed_mps = float(parameters["max_speed"])
		vehicle_profile.acceleration_mps2 = float(parameters["acceleration"])
		vehicle_profile.braking_mps2 = float(parameters["braking"])
		vehicle_profile.turn_rate_radians = float(parameters["turn_rate"])
		vehicle_profile.vehicle_mask = int(parameters["vehicle_mask"])
		var route_ids := PackedInt32Array()
		for raw_lane in item["route"]:
			route_ids.append(int(raw_lane))
		var car := VehicleScene.instantiate() as CivicVehicleAgent
		if car == null:
			valid = false
			break
		add_child(car)
		if not car.configure(road_graph, route_ids, vehicle_profile):
			car.free()
			valid = false
			break
		car.current_route_index = int(item["route_index"])
		var lane: CivicLaneData = road_graph.get_lane(car.route[car.current_route_index])
		car.lane_distance_m = minf(float(item["lane_distance"]), lane.length_m())
		car.speed_mps = float(item["speed"])
		car.target_speed_mps = float(item["target_speed"])
		car.stop_requested = bool(item["stop_requested"])
		car.physics_obstacle_checks_enabled = bool(item["obstacle_checks"])
		car.clear_lead_observation()
		car._place_on_lane()
		if car.footprint_blocked_at(car.global_transform):
			car.free()
			valid = false
			break
		for earlier in staged:
			var separation: Vector3 = car.global_position - earlier.global_position
			separation.y = 0.0
			if separation.length_squared() < 9.0:
				valid = false
				break
		if not valid:
			car.free()
			break
		staged.append(car)
		staged_delay[car.get_instance_id()] = float(item["delay"])
	if not valid:
		for created in staged:
			if is_instance_valid(created):
				created.free()
		for original in disabled:
			var restored_body: StaticBody3D = original["body"]
			if is_instance_valid(restored_body):
				restored_body.collision_layer = int(original["layer"])
		return false
	_prepared_restore = {"data": (data as Dictionary).duplicate(true),
		"staged": staged, "staged_delay": staged_delay, "old_layers": disabled}
	return true

func abort_restore() -> void:
	if not restore_prepared():
		return
	var prepared: Dictionary = _prepared_restore
	_prepared_restore = {}
	for created in prepared["staged"]:
		if is_instance_valid(created):
			created.free()
	for original in prepared["old_layers"]:
		var body: StaticBody3D = original["body"]
		if is_instance_valid(body):
			body.collision_layer = int(original["layer"])

func commit_restore() -> bool:
	if not restore_prepared():
		return false
	var prepared: Dictionary = _prepared_restore
	_prepared_restore = {}
	var data: Dictionary = prepared["data"]
	# Everything that might fail (route validity, collision queries and
	# instance construction) happened while the old cars were still present.
	for old in active_vehicles:
		if is_instance_valid(old):
			old.free()
	var new_generation: Array[CivicVehicleAgent] = []
	for car in prepared["staged"]:
		new_generation.append(car as CivicVehicleAgent)
	active_vehicles = new_generation
	_vehicle_delay = prepared["staged_delay"]
	# A committed checkpoint changes the authoritative traffic generation
	# and may move the logical clock backwards. Never retain a future decision
	# cursor or sensor observations from the generation that was replaced.
	work_budget.reset_runtime()
	current_tick = int(data["current_tick"])
	spawned_total = int(data["spawned_total"])
	completed_total = int(data["completed_total"])
	rejected_total = int(data["rejected_total"])
	total_delay_seconds = float(data["total_delay_seconds"])
	rng.state = int(data["rng_state"])
	return true

## Backwards-compatible one-shot API for isolated GAME-019 traffic tests.
func restore(data: Variant) -> bool:
	if not prepare_restore(data):
		return false
	return commit_restore()

func _exit_tree() -> void:
	# Avoid leaving colliders disabled if a scene is torn down mid-prepare.
	abort_restore()
