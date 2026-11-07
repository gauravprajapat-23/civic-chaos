extends SceneTree
## GAME-020: repeated failed loads must never leave colliders disabled or
## stage zombie vehicles. A successful commit replaces exactly one generation.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root_scene := Node3D.new()
    root.add_child(root_scene)
    var spawner := Spawner.new()
    spawner.maximum_active = 12
    spawner.spawn_interval_ticks = 3
    root_scene.add_child(spawner)
    if not spawner.configure(Builder.make_test_graph(), 1771):
        _fail("dense traffic setup failed")
        return
    for tick in range(1, 110):
        # Spawner may perform physical clearance queries on spawn ticks.
        await physics_frame
        spawner.advance_fixed(tick, 0.05)
    await physics_frame
    if spawner.active_vehicles.size() < 2:
        _fail("dense traffic fixture did not generate multiple physical cars")
        return
    var checkpoint: Variant = JSON.parse_string(JSON.stringify(spawner.snapshot()))
    if not spawner.can_restore(checkpoint):
        _fail("valid traffic data rejected")
        return
    var originals: Array[CivicVehicleAgent] = spawner.active_vehicles.duplicate()
    var original_layers: Array[int] = []
    var original_ids: Array[int] = []
    for car in originals:
        original_ids.append(car.get_instance_id())
        original_layers.append((car.get_node("CollisionBody") as StaticBody3D).collision_layer)

    for attempt in range(12):
        # Staged vehicle restoration performs physical swept/overlap probes.
        await physics_frame
        if not spawner.prepare_restore(checkpoint):
            _fail("prepare failed before explicit abort on attempt %d" % attempt)
            return
        if not spawner.restore_prepared() or spawner.prepare_restore(checkpoint):
            _fail("second concurrent prepare was accepted")
            return
        if spawner.active_vehicles.size() != originals.size():
            _fail("preflight changed running traffic generation")
            return
        # A rogue direct tick must not move cars or advance the spawner
        # while their live collision layers are temporarily disabled.
        var tick_before: int = spawner.current_tick
        var car_position: Vector3 = originals[0].global_position
        spawner.advance_fixed(tick_before + 1, 0.05)
        if spawner.current_tick != tick_before or originals[0].global_position.distance_to(car_position) > 0.001:
            _fail("simulation advanced while transaction was prepared")
            return
        spawner.abort_restore()
        if spawner.restore_prepared():
            _fail("abort left a pending traffic transaction")
            return
        for index in range(originals.size()):
            var car: CivicVehicleAgent = spawner.active_vehicles[index]
            if car != originals[index] or not is_instance_valid(car):
                _fail("abort destroyed an original traffic actor")
                return
            if (car.get_node("CollisionBody") as StaticBody3D).collision_layer != original_layers[index]:
                _fail("abort leaked disabled collision layer")
                return
        if spawner.current_tick != int(checkpoint["current_tick"]):
            _fail("abort mutated the logical traffic tick")
            return

    await physics_frame
    if not spawner.prepare_restore(checkpoint) or not spawner.commit_restore():
        _fail("commit after repeated aborts was unsuccessful")
        return
    if spawner.restore_prepared() or spawner.active_vehicles.size() != originals.size():
        _fail("commit leaked pending state or changed car count")
        return
    for index in range(originals.size()):
        var replacement: CivicVehicleAgent = spawner.active_vehicles[index]
        if not is_instance_valid(replacement) or replacement.get_instance_id() == original_ids[index]:
            _fail("commit failed to replace generation exactly once")
            return
        if (replacement.get_node("CollisionBody") as StaticBody3D).collision_layer != original_layers[index]:
            _fail("committed car lost collision layer")
            return
    if spawner.commit_restore():
        _fail("duplicate commit applied a second time")
        return
    root_scene.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_TRANSACTION_STRESS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
