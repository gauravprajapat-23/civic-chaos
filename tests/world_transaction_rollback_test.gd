extends SceneTree
## GAME-020: failed pedestrian preflight must not destroy the original city.
## Real physics colliders, car identities, RNG and fixed clocks are checked.
const Junction = preload("res://scripts/world/junction_scene.gd")
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var junction := Junction.new()
    junction.name = "FourWayJunction"
    stage.add_child(junction)
    var walkers := Walkers.new()
    walkers.name = "DistrictPedestrians"
    walkers.pedestrian_count = 1
    stage.add_child(walkers)
    walkers.configure_traffic(junction.traffic_signals, junction.traffic_spawner,
        junction.intersection_reservations)
    junction.traffic_spawner.maximum_active = 12
    junction.traffic_spawner.spawn_interval_ticks = 3
    for frame in range(200):
        await physics_frame
    junction.simulation.set_physics_process(false)
    walkers.set_physics_process(false)
    var state: Dictionary = junction.checkpoint_state(walkers)
    if not junction.checkpoint_valid(state, walkers):
        _fail("world cannot produce a coherent heavy-traffic checkpoint")
        return
    var previous: Array[CivicVehicleAgent] = junction.traffic_spawner.active_vehicles.duplicate()
    if previous.size() < 2:
        _fail("dense traffic fixture did not spawn two real vehicles")
        return
    var old_layers: Array[int] = []
    var old_positions: Array[Vector3] = []
    for car in previous:
        var body := car.get_node("CollisionBody") as StaticBody3D
        old_layers.append(body.collision_layer)
        old_positions.append(car.global_position)
    var last_rng: int = junction.traffic_spawner.rng.state
    var previous_tick: int = junction.simulation.clock.tick_index
    var witness_position: Vector3 = walkers._walkers[0]["root"].global_position

    var barricade := StaticBody3D.new()
    barricade.name = "CheckpointObstruction"
    barricade.collision_layer = 1
    barricade.collision_mask = 0
    barricade.position = witness_position + Vector3.UP * 0.9
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(1.0, 1.8, 1.0)
    shape.shape = box
    barricade.add_child(shape)
    stage.add_child(barricade)
    await physics_frame

    if junction.restore_checkpoint(state, walkers):
        _fail("occupied pedestrian destination was restored through a barricade")
        return
    if junction.traffic_spawner.restore_prepared():
        _fail("failed transaction left a replacement traffic generation staged")
        return
    if junction.traffic_spawner.active_vehicles.size() != previous.size():
        _fail("failure changed live car count")
        return
    for index in range(previous.size()):
        var existing: CivicVehicleAgent = junction.traffic_spawner.active_vehicles[index]
        if existing != previous[index] or not is_instance_valid(existing):
            _fail("rollback destroyed and recreated an original vehicle")
            return
        if existing.global_position.distance_to(old_positions[index]) > 0.001:
            _fail("rollback moved the original car")
            return
        if (existing.get_node("CollisionBody") as StaticBody3D).collision_layer != old_layers[index]:
            _fail("rollback did not restore original vehicle collision layers")
            return
    if junction.traffic_spawner.rng.state != last_rng or junction.simulation.clock.tick_index != previous_tick:
        _fail("failed load mutated live RNG or simulation clock")
        return
    if walkers._walkers[0]["root"].global_position.distance_to(witness_position) > 0.001:
        _fail("failed load moved the original pedestrian")
        return
    barricade.queue_free()
    await physics_frame
    await physics_frame
    if not junction.restore_checkpoint(state, walkers):
        _fail("valid snapshot could not restore after physical obstruction removal")
        return
    if junction.traffic_spawner.restore_prepared():
        _fail("successful transaction retained staged generation")
        return
    if junction.simulation.clock.tick_index != previous_tick:
        _fail("committed world clock changed unexpectedly")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_WORLD_TRANSACTION_ROLLBACK_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
