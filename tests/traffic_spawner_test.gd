extends SceneTree

const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var spawner := Spawner.new()
    root.add_child(spawner)
    spawner.spawn_interval_ticks = 10
    spawner.maximum_active = 20
    if not spawner.configure(Builder.make_test_graph(), 5678):
        _fail("valid graph rejected")
        return
    for tick in range(1, 1601):
        # Vehicle spawn clearance uses World3D.direct_space_state.
        # Run the fixed tick only when physics-space queries are unlocked.
        await physics_frame
        spawner.advance_fixed(tick, 0.05)
        if spawner.active_vehicles.size() > 20:
            _fail("active cap exceeded")
            return
        for vehicle in spawner.active_vehicles:
            if vehicle.route.size() != 2 or not spawner.road_graph.outgoing_legal_lanes(vehicle.route[0], 1).has(vehicle.route[1]):
                _fail("invalid spawned route")
                return
    var result := spawner.metrics()
    if result["spawned"] < 20 or result["completed"] < 1 or result["throughput_per_minute"] <= 0.0:
        _fail("20-agent demand or throughput assertion failed")
        return
    if result["queue"] < 0 or result["delay_seconds"] < 0.0:
        _fail("invalid metrics")
        return
    spawner.queue_free()
    print("CIVIC_CHAOS_SPAWNER_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
