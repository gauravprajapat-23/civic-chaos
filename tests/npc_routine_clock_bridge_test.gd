extends SceneTree
## GAME-025-A3 gated preview: same fixed-step city tick drives daily agendas.
const Director = preload("res://scripts/core/simulation_director.gd")
const Pedestrians = preload("res://scripts/npc/district_pedestrians.gd")
const Bridge = preload("res://scripts/npc/npc_routine_clock_bridge.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var simulation := Director.new() as SimulationDirector
    world.add_child(simulation)
    var pedestrians := Pedestrians.new()
    pedestrians.pedestrian_count = 0
    world.add_child(pedestrians)
    var bridge := Bridge.new() as CivicNPCRoutineClockBridge
    if bridge.attach(simulation, pedestrians):
        _fail("preview-disabled pedestrians accepted an unauthorized clock bridge")
        return
    if not pedestrians.configure_daily_routine_preview():
        _fail("isolated clock test could not opt in")
        return
    if not bridge.attach(simulation, pedestrians) or not bridge.attached():
        _fail("explicitly enabled preview did not bind to the city's fixed clock")
        return
    if bridge.attach(simulation, pedestrians):
        _fail("duplicate bridge connection was accepted")
        return
    for frame in range(35):
        await physics_frame
    var observed: int = simulation.clock.tick_index
    if observed <= 0 or bridge.last_tick() != observed:
        _fail("NPC schedule did not follow authoritative simulation ticks")
        return
    var snapshot: Dictionary = pedestrians.checkpoint_state()
    if snapshot["schema_version"] != 2:
        _fail("enabled preview did not create v2 checkpoint")
        return
    if int(snapshot["routine_checkpoint"]["tick"]) != observed:
        _fail("routine time diverged from the city simulation")
        return
    simulation.set_simulation_paused(true)
    for frame in range(10):
        await physics_frame
    if bridge.last_tick() != observed or simulation.clock.tick_index != observed:
        _fail("paused city clock advanced the NPC agenda")
        return
    simulation.set_simulation_paused(false)
    for frame in range(15):
        await physics_frame
    var resumed: int = simulation.clock.tick_index
    if resumed <= observed or bridge.last_tick() != resumed:
        _fail("daily agenda failed to resume with the city's fixed-step clock")
        return
    bridge.detach()
    if bridge.attached() or bridge.last_tick() != -1:
        _fail("clock bridge did not disconnect")
        return
    for frame in range(15):
        await physics_frame
    if simulation.clock.tick_index <= resumed:
        _fail("fixture's city clock stopped after detaching the NPC bridge")
        return
    if int(pedestrians.checkpoint_state()["routine_checkpoint"]["tick"]) != resumed:
        _fail("detached bridge still mutated the NPC schedule")
        return
    world.queue_free()
    print("CIVIC_CHAOS_NPC_ROUTINE_CLOCK_BRIDGE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
