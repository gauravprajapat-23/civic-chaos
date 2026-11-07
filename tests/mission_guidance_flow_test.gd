extends SceneTree
## GAME-015 — guide follows real civic stages; a timeout never awards rewards.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    player.position = Vector3(18, 0, 12)
    stage.add_child(player)
    var civic := Session.new()
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("tutorial setup failed")
        return
    var tutorial: Dictionary = civic.guidance_state()
    if not bool(tutorial.get("has_target", false)) or not tutorial["objective"].contains("Inspect"):
        _fail("tutorial not guiding the actual obstruction")
        return
    civic.missions.record_event(Session.MISSION_ID, "obstruction_observed")
    if not civic.guidance_state()["objective"].contains("report"):
        _fail("tutorial did not guide to the reporting step")
        return
    var live := Live.new()
    stage.add_child(live)
    if not live.configure(stage, player, Builder.make_city_graph(), civic):
        _fail("wrong-way live scenario failed to stage")
        return
    live.set_physics_process(false)
    var initial: Dictionary = live.guidance_state()
    if not initial["has_target"] or initial["target"] != live.marker.global_position:
        _fail("wrong-way waypoint does not reference the real post")
        return
    if initial["recovery_available"]:
        _fail("unreported event was incorrectly considered stalled")
        return
    # A deliberately frozen clock represents a stuck service, not a
    # physical traffic recovery. The test only inspects UI diagnostics.
    live.reported_tick = 1
    live.tick = 1
    live._update_recovery_watchdog()
    live.tick = Live.RECOVERY_STALL_TICKS + 2
    live._update_recovery_watchdog()
    if not live.recovery_help_needed() or not live.guidance_state()["recovery_available"]:
        _fail("stalled service did not expose voluntary retry controls")
        return
    if civic.missions.missions[Live.MISSION_ID]["state"] != CivicMissionManager.ACTIVE:
        _fail("stalled service silently failed/completed the civic mission")
        return
    if civic.missions.claim_reward(Live.MISSION_ID) != 0:
        _fail("recovery prompt incorrectly awarded mission reward")
        return
    live.tow_started = true
    live.tow_progress_m = Live.OFFENDER_DISTANCE + Live.TOW_GAP_M + 2.0
    live._update_recovery_watchdog()
    if live.recovery_help_needed():
        _fail("actual tow progress did not clear stalled warning")
        return
    stage.queue_free()
    await process_frame
    print("CIVIC_CHAOS_MISSION_GUIDANCE_FLOW_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
