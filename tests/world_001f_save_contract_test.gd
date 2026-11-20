extends SceneTree
## WORLD-001F: old schema-1 traffic save payloads must still be accepted
## or safely rejected without altering live traffic state.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
var failures: int = 0

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-001F: " + message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    _check(graph.validate().is_empty() and graph.lane_count() == 80,
        "the legacy city graph was changed")
    var historic_ids: Array[int] = graph.sorted_lane_ids()
    _check(historic_ids.size() == 80 and historic_ids[0] == 100 and
        historic_ids[historic_ids.size() - 1] == 179,
        "old lane identifiers are not stable")
    _check(Network.SCHEMA_VERSION == 1,
        "network schema unexpectedly changed without explicit migration")

    var spawner: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    _check(spawner.configure(graph, 4701, true),
        "city spawner could not configure canonical graph")
    root.add_child(spawner)
    await physics_frame
    var pilot: CivicLaneData = graph.get_lane(102)
    var possible: Array[int] = graph.outgoing_legal_lanes(102, 1)
    _check(not possible.is_empty(), "west pilot has no compatible route after its T")
    if possible.is_empty() or pilot == null:
        spawner.free()
        quit(1)
        return
    var car := CivicVehicleAgent.new()
    var route := PackedInt32Array([102, possible[0]])
    _check(car.configure(graph, route, Profile.new()),
        "unable to configure existing saved lane route")
    car.lane_distance_m = minf(pilot.length_m() * 0.5, 34.0)
    spawner.active_vehicles.append(car)
    spawner.spawned_total = 1
    var snapshot: Dictionary = spawner.snapshot()
    var json_value: Variant = JSON.parse_string(JSON.stringify(snapshot))
    _check(json_value is Dictionary, "schema-1 traffic snapshot JSON invalid")
    _check(spawner.can_restore(json_value),
        "existing schema-1 snapshot rejected by curved-road graph")

    # A valid checkpoint retains route ID, slot and progress while the
    # physical vehicle moves on the new lane's geometry after loading.
    var state: Dictionary = json_value
    var cars: Array = state["cars"]
    _check(cars.size() == 1, "active saved car was not serialized")
    if cars.size() == 1:
        var saved: Dictionary = cars[0]
        _check(int((saved["route"] as Array)[0]) == 102 and
            int(saved["route_index"]) == 0 and
            absf(float(saved["lane_distance"]) - car.lane_distance_m) < 0.01,
            "legacy route identity or progress was changed")

    # Invalid route/distance must not stage replacement actors, counters,
    # or mutate the active vehicle. Guard the exact same rejection path
    # used by real checkpoint preflights.
    var before_count: int = spawner.active_vehicles.size()
    var before_distance: float = car.lane_distance_m
    var bad: Dictionary = (json_value as Dictionary).duplicate(true)
    var invalid_car: Dictionary = (bad["cars"] as Array)[0]
    var invalid_route: Array = invalid_car["route"]
    invalid_route[0] = 999999
    _check(not spawner.can_restore(bad), "unknown lane accepted on restore")
    _check(spawner.active_vehicles.size() == before_count and
        absf(car.lane_distance_m - before_distance) < 0.01,
        "rejected restore mutated the live fleet")
    bad = (json_value as Dictionary).duplicate(true)
    invalid_car = (bad["cars"] as Array)[0]
    invalid_car["lane_distance"] = pilot.length_m() + 1.0
    _check(not spawner.can_restore(bad),
        "out-of-range progress accepted by the revised pilot")
    _check(not spawner.restore_prepared(),
        "invalid preflight created an uncommitted transaction")

    # Valid record can stage, then abort without destroying existing fleet.
    _check(spawner.prepare_restore(json_value),
        "valid traffic checkpoint failed to stage replacement")
    _check(spawner.restore_prepared(), "valid staging did not enter prepared mode")
    spawner.abort_restore()
    _check(not spawner.restore_prepared() and
        spawner.active_vehicles.size() == before_count,
        "abort failed to retain the live fleet")
    spawner.active_vehicles.clear()
    car.free()
    spawner.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_001F_SAVE_CONTRACT_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_001F_SAVE_CONTRACT_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
