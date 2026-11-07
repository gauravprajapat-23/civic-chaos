extends SceneTree
## GAME-025-A3: the real walker may pause only at a clear sidewalk stop.
## Tests opt-in preview explicitly. The playable game never calls it.
const Pedestrians = preload("res://scripts/npc/district_pedestrians.gd")
const Routines = preload("res://scripts/npc/npc_daily_routines.gd")
const Stops = preload("res://scripts/npc/npc_routine_waypoints.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var walkers := Pedestrians.new()
    walkers.pedestrian_count = 1
    stage.add_child(walkers)
    walkers.set_physics_process(false)
    if walkers._walkers.size() != 1:
        _fail("physical NPC did not spawn")
        return
    if walkers.daily_routine_preview_enabled() or walkers.checkpoint_state()["schema_version"] != 1:
        _fail("preview is unexpectedly enabled in the baseline pedestrian")
        return
    var legacy: Dictionary = walkers.checkpoint_state()
    var empty_reservations: Dictionary = {"occupied": {}}
    if not walkers.checkpoint_valid(legacy, empty_reservations):
        _fail("original v1 pedestrian checkpoint was rejected")
        return
    if not walkers.configure_daily_routine_preview() or walkers.configure_daily_routine_preview():
        _fail("preview enablement was not explicit and single-use")
        return
    if not walkers.advance_daily_routine_tick(Routines.PHASE_TICKS):
        _fail("world simulation tick did not drive routine schedule")
        return
    if walkers.advance_daily_routine_tick(Routines.PHASE_TICKS - 1):
        _fail("routine clock moved backward")
        return
    var half_length: float = walkers.district_extent * 1.65 * 0.5
    var stop: float = Stops.target_progress("market_stall", walkers.district_extent, 0)
    var actor: Node3D = walkers._walkers[0]["root"]
    if not Stops.is_safe_progress(stop, half_length):
        _fail("shopkeeper waypoint is inside intersection conflict")
        return
    # Begin on the approach, not teleported to the stop by the routine
    # controller. The existing movement logic must advance there.
    var initial: float = stop - 0.8
    walkers._walker_progress[0] = half_length + initial
    actor.position = walkers._walk_position(0, initial)
    var before: Vector3 = actor.position
    for step in range(14):
        walkers._physics_process(0.1)
    if actor.position.distance_to(before) < 0.15:
        _fail("NPC never travelled along the original sidewalk")
        return
    var resting: Dictionary = walkers.daily_routine_preview_state(0)
    if resting.get("mode") != "perform_activity" or not bool(resting.get("pause_for_activity", false)):
        _fail("shopkeeper missed a clear activity stop")
        return
    var at_rest: Vector3 = actor.position
    for step in range(10):
        walkers._physics_process(0.1)
    if actor.position.distance_to(at_rest) > 0.001 or walkers._blocked_frames[0] != 0:
        _fail("scheduled rest moved actor or counted as stuck")
        return
    # Even at an arrived stop, held crossing ownership takes precedence.
    walkers._crossing[0] = true
    var held: Dictionary = walkers.daily_routine_preview_state(0)
    if held.get("mode") != "crossing_authority" or bool(held.get("pause_for_activity", false)):
        _fail("schedule seized authority from occupied pedestrian crossing")
        return
    walkers._crossing[0] = false
    var player := Node3D.new()
    player.name = "PlayerRoot"
    player.position = actor.global_position
    stage.add_child(player)
    var exposed: Dictionary = walkers.daily_routine_preview_state(0)
    if bool(exposed.get("pause_for_activity", false)):
        _fail("NPC continued stationary activity inside player clearance")
        return
    player.queue_free()
    await physics_frame
    # A schedule change must unfreeze the same physical actor and never
    # reset its logical route or crossing reservation.
    var old_progress: float = walkers._walker_progress[0]
    if not walkers.advance_daily_routine_tick(Routines.PHASE_TICKS * 2):
        _fail("new day phase failed to advance")
        return
    for step in range(5):
        walkers._physics_process(0.1)
    if walkers._walker_progress[0] <= old_progress + 0.1:
        _fail("shopkeeper stayed stuck after shift ended")
        return
    var snapshot: Dictionary = walkers.checkpoint_state()
    if snapshot.get("schema_version") != 2 or not snapshot.has("routine_checkpoint"):
        _fail("opt-in routine clock was not included in walker checkpoint")
        return
    var serialized: Variant = JSON.parse_string(JSON.stringify(snapshot))
    if not walkers.checkpoint_valid(serialized, empty_reservations):
        _fail("genuine v2 pedestrian checkpoint refused")
        return
    if walkers.checkpoint_valid(legacy, empty_reservations):
        _fail("legacy v1 save silently reset an active routine clock")
        return
    var forged: Dictionary = (serialized as Dictionary).duplicate(true)
    forged["routine_checkpoint"]["tick"] = Routines.PHASE_TICKS * 3
    if walkers.checkpoint_valid(forged, empty_reservations):
        _fail("routine checkpoint accepted a new phase with stale role activities")
        return
    forged = (serialized as Dictionary).duplicate(true)
    forged["routine_checkpoint"]["agents"][0]["activity"] = "teleport"
    if walkers.checkpoint_valid(forged, empty_reservations):
        _fail("forged routine activity accepted")
        return
    var saved_tick: int = int(walkers._daily_routine_adapter.checkpoint_state()["tick"])
    if walkers.restore_checkpoint(forged, empty_reservations):
        _fail("invalid checkpoint mutated an active NPC")
        return
    if int(walkers._daily_routine_adapter.checkpoint_state()["tick"]) != saved_tick:
        _fail("rejected checkpoint changed routine clock")
        return
    if not walkers.restore_checkpoint(serialized, empty_reservations):
        _fail("valid v2 pedestrian checkpoint failed restoration")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_NPC_ROUTINE_PREVIEW_PHYSICS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
