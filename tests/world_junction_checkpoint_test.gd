extends SceneTree
## GAME-019: coherent world clocks, legal traffic, signal phases and
## pedestrian-crossing permissions from one JSON checkpoint.
const Junction = preload("res://scripts/world/junction_scene.gd")
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var junction := Junction.new()
    junction.name = "FourWayJunction"
    world.add_child(junction)
    var walkers := Walkers.new()
    walkers.name = "DistrictPedestrians"
    walkers.pedestrian_count = 0
    world.add_child(walkers)
    walkers.configure_traffic(junction.traffic_signals, junction.traffic_spawner, junction.intersection_reservations)
    junction.traffic_spawner.spawn_interval_ticks = 5
    for frame in range(80):
        await physics_frame
    junction.simulation.set_physics_process(false)
    walkers.set_physics_process(false)
    var saved: Dictionary = junction.checkpoint_state(walkers)
    if not junction.checkpoint_valid(saved, walkers):
        _fail("real junction world state not internally consistent")
        return
    var saved_tick: int = int(saved["clock"]["tick_index"])
    if saved_tick <= 0 or saved_tick != int(saved["traffic"]["current_tick"]) or saved_tick != int(saved["reservations"]["current_tick"]):
        _fail("saved world managers disagree on simulation tick")
        return
    var json_state: Variant = JSON.parse_string(JSON.stringify(saved))
    if not junction.checkpoint_valid(json_state, walkers):
        _fail("world checkpoint did not round-trip through JSON")
        return
    var corrupt: Dictionary = (json_state as Dictionary).duplicate(true)
    corrupt["reservations"]["current_tick"] = saved_tick - 1
    if junction.checkpoint_valid(corrupt, walkers):
        _fail("out-of-sync crossing reservation clock was accepted")
        return
    corrupt = (json_state as Dictionary).duplicate(true)
    corrupt["signals"]["phase"] = 10
    if junction.checkpoint_valid(corrupt, walkers):
        _fail("invalid green-phase value was accepted")
        return
    var active_before: int = junction.traffic_spawner.active_vehicles.size()
    if not junction.restore_checkpoint(json_state, walkers):
        _fail("legitimate frozen world checkpoint did not restore")
        return
    if junction.traffic_spawner.active_vehicles.size() != active_before or junction.simulation.clock.tick_index != saved_tick:
        _fail("background traffic or clock changed during restore")
        return
    if junction.traffic_signals.snapshot()["phase"] != saved["signals"]["phase"]:
        _fail("traffic signal phase changed during restore")
        return
    junction.simulation.set_physics_process(true)
    if junction.restore_checkpoint(json_state, walkers):
        _fail("junction restore ran while fixed-step simulation was active")
        return
    junction.simulation.set_physics_process(false)

    # Existing crossing occupancy must persist after JSON conversion, not be
    # lost because Godot serializes PackedStringArray as an untyped Array.
    var reservations := Reservations.new()
    if not reservations.request(100000, PackedStringArray(["pedestrian_crossing_ew"]), 1, 600)["granted"]:
        _fail("could not create physical crossing permission")
        return
    if not reservations.advance_to(10) or not reservations.occupy(100000, "pedestrian_crossing_ew"):
        _fail("crossing permission could not be occupied")
        return
    var held: Variant = JSON.parse_string(JSON.stringify(reservations.snapshot()))
    var reconstructed := Reservations.new()
    if not reconstructed.restore(held) or reconstructed.occupant("pedestrian_crossing_ew") != 100000:
        _fail("occupied crossing was not preserved on restart")
        return
    if reconstructed.request(100001, PackedStringArray(["pedestrian_crossing_ew"]), 10, 20)["reason"] != "occupied":
        _fail("restored reserved crossing failed to protect a pedestrian")
        return
    var tampered: Dictionary = (held as Dictionary).duplicate(true)
    tampered["occupied"]["pedestrian_crossing_ew"] = -1
    if reconstructed.can_restore(tampered):
        _fail("forged negative crossing owner was accepted")
        return

    world.queue_free()
    print("CIVIC_CHAOS_WORLD_JUNCTION_CHECKPOINT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
