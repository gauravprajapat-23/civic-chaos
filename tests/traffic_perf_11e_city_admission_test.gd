extends SceneTree
## TRAFFIC-PERF-11E — Four-direction junction throughput cannot absorb
## 1 car / 30 ticks at a 20-car cap during real incident blockages.
## Verify safe entry pacing, early queue backpressure, finite drain,
## municipal/tow discharge admission holds and legacy fixture isolation.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if Spawner.city_soft_congested(4, 4) or (
            not Spawner.city_soft_congested(8, 4)) or (
            Spawner.city_soft_congested(8, 3)):
        _fail("city early-pressure threshold is not 5 cars at 50 percent stopped")
        return
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 43, true):
        _fail("city graph configure failed")
        return
    if spawner.city_admission_blocked():
        _fail("empty city must admit initial cars")
        return
    var spawned: int = 0
    for tick in range(1, 161):
        await physics_frame
        spawner.advance_fixed(tick, 0.05)
        if spawner.spawned_total > spawned and tick % Spawner.CITY_SPAWN_PERIOD_TICKS != 0:
            _fail("city still spawns at aggressive old 30-tick cadence")
            return
        spawned = spawner.spawned_total
    if spawned < 1:
        _fail("slow paced city did not admit any valid traffic")
        return
    # A real municipal service makes ordinary *arrival* admission zero,
    # without changing active traffic, RNG or completion accounting.
    var service := CivicVehicleAgent.new()
    service.active = true
    service.route = spawner.active_vehicles[0].route.duplicate()
    spawner.set_central_service_priority(service)
    var before: int = spawner.spawned_total
    var rejected: int = spawner.rejected_total
    var rng_state: int = spawner.rng.state
    if not spawner.city_admission_blocked() or spawner.try_spawn():
        _fail("active municipal convoy admitted new city arrival")
        return
    if spawner.spawned_total != before or spawner.rejected_total != rejected or spawner.rng.state != rng_state:
        _fail("blocked admission consumed RNG or fabricated rejection")
        return
    spawner.clear_central_service_priority(service)
    var follower := spawner.active_vehicles[0]
    var followers: Array[CivicVehicleAgent] = [follower]
    if not spawner.start_central_recovery(followers, 300):
        _fail("post-tow recovery window refused")
        return
    if not spawner.city_admission_blocked() or spawner.try_spawn():
        _fail("post-tow queue release admitted unrelated new vehicles")
        return
    spawner.clear_central_recovery()
    # Eight physically stopped cars (not synthetic counters) form a queue,
    # triggering an additional 4-second drain rather than more spawning.
    for car in spawner.active_vehicles:
        car.speed_mps = 0.0
    var added: Array[CivicVehicleAgent] = []
    while spawner.active_vehicles.size() < 8:
        var car := CivicVehicleAgent.new()
        car.active = true
        car.speed_mps = 0.0
        car.route = follower.route.duplicate()
        car.current_route_index = 0
        spawner.active_vehicles.append(car)
        added.append(car)
    spawner.current_tick = 200
    spawner._update_city_drain()
    if not spawner.city_admission_blocked() or spawner.try_spawn():
        _fail("real crowded lane failed early backpressure")
        return
    for car in spawner.active_vehicles:
        car.speed_mps = 4.0
    spawner.current_tick = 201
    if not spawner.city_admission_blocked():
        _fail("one moving frame cancelled queue drain hysteresis")
        return
    spawner.current_tick = 281
    if spawner.city_admission_blocked():
        _fail("real queue recovery did not reopen admission after hysteresis")
        return
    # Existing checkpoint populations can be larger than the new city
    # admission cap; no actor may be despawned as an optimization.
    while spawner.active_vehicles.size() < Spawner.CITY_MOVING_FLEET_LIMIT:
        var car := CivicVehicleAgent.new()
        car.active = true
        car.speed_mps = 4.0
        car.route = follower.route.duplicate()
        spawner.active_vehicles.append(car)
        added.append(car)
    if spawner.try_spawn():
        _fail("city fleet cap was exceeded by direct spawn")
        return
    if spawner.active_vehicles.size() != Spawner.CITY_MOVING_FLEET_LIMIT:
        _fail("city admission changed live vehicle count")
        return
    for car in added:
        spawner.active_vehicles.erase(car)
        car.free()
    service.free()
    spawner.queue_free()
    # Test graphs without expanded city retain old deterministic demand.
    var legacy := Spawner.new() as CivicTrafficSpawner
    root.add_child(legacy)
    if not legacy.configure(Builder.make_test_graph(), 43, false):
        _fail("legacy graph rejected")
        return
    if legacy.city_admission_blocked() or legacy.try_spawn() == false:
        _fail("city pacing incorrectly changed old fixture demand")
        return
    legacy.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_PERF_11E_CITY_ADMISSION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
