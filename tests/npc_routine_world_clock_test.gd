extends SceneTree
## GAME-025-A3: routine time is part of the background world transaction,
## not a free-running second clock. Disabled baseline remains schema v1.
const Junction = preload("res://scripts/world/junction_scene.gd")
const Pedestrians = preload("res://scripts/npc/district_pedestrians.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var junction := Junction.new()
    junction.name = "FourWayJunction"
    world.add_child(junction)
    var walkers := Pedestrians.new()
    walkers.name = "DistrictPedestrians"
    walkers.pedestrian_count = 0
    world.add_child(walkers)
    for frame in range(12):
        await physics_frame
    junction.simulation.set_physics_process(false)
    walkers.set_physics_process(false)
    var baseline: Dictionary = junction.checkpoint_state(walkers)
    if not junction.checkpoint_valid(baseline, walkers):
        _fail("baseline world checkpoint is invalid")
        return
    if baseline["pedestrians"]["schema_version"] != 1:
        _fail("disabled routine preview changed existing save schema")
        return
    if not walkers.configure_daily_routine_preview():
        _fail("could not opt into test-only routine preview")
        return
    var tick: int = junction.simulation.clock.tick_index
    if not walkers.advance_daily_routine_tick(tick):
        _fail("preview could not synchronize to world tick")
        return
    var saved: Dictionary = junction.checkpoint_state(walkers)
    if int(saved["pedestrians"]["schema_version"]) != 2:
        _fail("enabled routine preview did not issue walker schema v2")
        return
    if not junction.checkpoint_valid(saved, walkers):
        _fail("coherent routine and city clock was rejected")
        return
    var forged: Dictionary = saved.duplicate(true)
    forged["pedestrians"]["routine_checkpoint"]["tick"] = tick + 1
    # The derived agenda is identical at the adjacent tick, so the model
    # alone accepts it; only the world transaction may reject the mismatch.
    if not walkers.checkpoint_valid(forged["pedestrians"], forged["reservations"]):
        _fail("fixture did not create an otherwise-valid altered routine tick")
        return
    if junction.checkpoint_valid(forged, walkers):
        _fail("cross-system checkpoint accepted two distinct time sources")
        return
    var roundtrip: Variant = JSON.parse_string(JSON.stringify(saved))
    if not junction.checkpoint_valid(roundtrip, walkers):
        _fail("JSON round-trip broke linked world and NPC routine clocks")
        return
    if not junction.restore_checkpoint(roundtrip, walkers):
        _fail("matching routine/world tick failed atomic restore")
        return
    world.queue_free()
    print("CIVIC_CHAOS_NPC_ROUTINE_WORLD_CLOCK_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
