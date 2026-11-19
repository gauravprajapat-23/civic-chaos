extends SceneTree
## CAR-SAFE-05: backpressure is deterministic and never changes safety
## permissions, traffic RNG, checkpoint schema or rejection accounting.
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Vehicle = preload("res://scripts/traffic/vehicle_agent.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if Spawner.congestion_backpressure(2, 2):
        _fail("a two-car crossing was falsely classified as gridlock")
        return
    if not Spawner.congestion_backpressure(4, 3):
        _fail("3 of 4 stopped vehicles must trigger backpressure")
        return
    if Spawner.congestion_backpressure(4, 2):
        _fail("normal waiting queue was classified as gridlock")
        return

    var stage := Node3D.new()
    root.add_child(stage)
    var spawner: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    stage.add_child(spawner)
    var graph: CivicRoadGraph = Builder.make_test_graph()
    if not spawner.configure(graph, 5353):
        _fail("test road graph rejected")
        return
    # Pure vehicle agents without physics bodies are intentional. Test
    # spawn admission behavior, not the route simulation in this fixture.
    for i in range(4):
        var car: CivicVehicleAgent = Vehicle.new() as CivicVehicleAgent
        car.feedback_enabled = false
        stage.add_child(car)
        car.active = true
        car.speed_mps = 0.0 if i < 3 else 1.0
        spawner.active_vehicles.append(car)
    var rng_state: int = spawner.rng.state
    var rejected: int = spawner.rejected_total
    if not bool(spawner.queue_pressure()["congested"]):
        _fail("live queue was not recognized as congested")
        return
    if spawner.try_spawn():
        _fail("spawn bypassed congested queue")
        return
    if spawner.rng.state != rng_state or spawner.rejected_total != rejected:
        _fail("deferred demand consumed RNG or inflated rejection counter")
        return
    if not bool(spawner.metrics()["congested"]):
        _fail("queue congestion is missing from diagnostic metrics")
        return
    spawner.active_vehicles[0].speed_mps = 1.0
    if bool(spawner.queue_pressure()["congested"]):
        _fail("backpressure did not release after traffic moved")
        return
    if bool(spawner.metrics()["congested"]):
        _fail("performance telemetry continued claiming congestion")
        return
    # The snapshot schema remains unchanged to preserve legacy saves.
    if spawner.snapshot().has("spawn_backpressure_ticks"):
        _fail("ephemeral traffic telemetry leaked into save data")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_CAR_SAFE_05_BACKPRESSURE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
