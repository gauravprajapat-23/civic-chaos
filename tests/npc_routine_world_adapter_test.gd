extends SceneTree
## GAME-025-A3: inspect a *real spawned pedestrian*, but never attach this
## adapter to the live game until GAME-024 Godot verification is accepted.
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")
const Adapter = preload("res://scripts/npc/npc_routine_world_adapter.gd")
const Routines = preload("res://scripts/npc/npc_daily_routines.gd")
const Stops = preload("res://scripts/npc/npc_routine_waypoints.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var pedestrians := Walkers.new()
    pedestrians.pedestrian_count = 1
    stage.add_child(pedestrians)
    pedestrians.set_physics_process(false)
    if pedestrians._walkers.size() != 1:
        _fail("no physical NPC available for the routine adapter")
        return
    var adapter := Adapter.new() as CivicNPCRoutineWorldAdapter
    if not adapter.configure(1) or adapter.configure(1):
        _fail("routine adapter configured more than once")
        return
    if not adapter.inspect_walker(pedestrians, 1).is_empty():
        _fail("nonexistent NPC gained movement intent")
        return
    # Agent zero is a shopkeeper for the default seed. Workday shopkeeping
    # is a stationary job; the stop must be away from the junction.
    if Routines.role_for(0) != "shopkeeper":
        _fail("default seed no longer provides stationary shopkeeper test case")
        return
    if not adapter.advance_to_simulation_tick(Routines.PHASE_TICKS):
        _fail("deterministic day tick did not advance")
        return
    var state: Dictionary = adapter.inspect_walker(pedestrians, 0)
    if state.is_empty() or state["mode"] != "walk_existing_route":
        _fail("pedestrian incorrectly performed activity before arrival")
        return
    var half_length: float = pedestrians.district_extent * 1.65 * 0.5
    var target_progress: float = Stops.target_progress("market_stall", pedestrians.district_extent, 0)
    if not Stops.is_safe_progress(target_progress, half_length):
        _fail("shopkeeper waypoint is unsafe or within junction conflict")
        return
    pedestrians._walkers[0]["root"].position = pedestrians._walk_position(0, target_progress)
    pedestrians._walker_progress[0] = half_length + target_progress
    await physics_frame
    state = adapter.inspect_walker(pedestrians, 0)
    if state.is_empty() or state["mode"] != "perform_activity" or not bool(state["pause_for_activity"]):
        _fail("shopkeeper did not recognize clear real sidewalk waypoint")
        return
    if not bool(state["at_safe_stop"]) or state["activity"] != "serve_customers":
        _fail("safe shop activity destination is missing")
        return
    pedestrians._crossing[0] = true
    state = adapter.inspect_walker(pedestrians, 0)
    if state["mode"] != "crossing_authority" or bool(state["pause_for_activity"]):
        _fail("held reservation did not cancel scheduled stationary activity")
        return
    pedestrians._crossing[0] = false

    # Proximity to a real player must prevent waiting, even on a valid anchor.
    var player := Node3D.new()
    player.name = "PlayerRoot"
    player.position = pedestrians._walkers[0]["root"].global_position
    stage.add_child(player)
    state = adapter.inspect_walker(pedestrians, 0)
    if bool(state["at_safe_stop"]) or bool(state["pause_for_activity"]):
        _fail("NPC paused on top of the player at a nominally safe waypoint")
        return
    player.queue_free()
    await physics_frame
    var current: Node3D = pedestrians._walkers[0]["root"]
    var saved_position: Vector3 = current.position

    # A root body sidestepped far off the sidewalk is not considered arrived.
    current.position = saved_position + Vector3(2.0, 0.0, 0.0)
    state = adapter.inspect_walker(pedestrians, 0)
    if bool(state["at_safe_stop"]):
        _fail("sidestepped pedestrian was accepted as safely parked")
        return
    current.position = saved_position

    # Even a forged progress number cannot make an NPC stop on the roadway.
    pedestrians._walker_progress[0] = half_length
    current.position = pedestrians._walk_position(0, 0.0)
    state = adapter.inspect_walker(pedestrians, 0)
    if state["mode"] != "crossing_authority" or bool(state["pause_for_activity"]):
        _fail("physical crossing check failed to veto idle behavior")
        return

    var snapshot: Variant = JSON.parse_string(JSON.stringify(adapter.checkpoint_state()))
    if not adapter.checkpoint_valid(snapshot):
        _fail("valid routine state could not be serialized")
        return
    var bad: Dictionary = (snapshot as Dictionary).duplicate(true)
    bad["agents"][0]["activity"] = "teleport_home"
    if adapter.restore_checkpoint(bad):
        _fail("forged checkpoint overwrote deterministic routine state")
        return
    var fresh := Adapter.new() as CivicNPCRoutineWorldAdapter
    if not fresh.configure(1) or not fresh.restore_checkpoint(snapshot):
        _fail("fresh routine adapter failed JSON restoration")
        return
    if fresh.checkpoint_state() != adapter.checkpoint_state():
        _fail("freshly restored routine diverged from original agenda")
        return

    stage.queue_free()
    print("CIVIC_CHAOS_NPC_ROUTINE_WORLD_ADAPTER_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
