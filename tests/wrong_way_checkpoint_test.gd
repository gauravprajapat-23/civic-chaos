extends SceneTree
## GAME-014 — real JSON checkpoint through marshal/tow scene reconstruction.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")
const Lifecycle = preload("res://scripts/core/game_lifecycle.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")
const SAVE_PATH := "user://game014_wrong_way_checkpoint_test.json"

func _initialize() -> void:
    call_deferred("_run")

func _world_with_road() -> Node3D:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.name = "RoadSupport"
    floor.position = Vector3(0.0, -0.25, 0.0)
    floor.collision_layer = 1
    floor.collision_mask = 0
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(140, 0.5, 24)
    shape.shape = box
    floor.add_child(shape)
    stage.add_child(floor)
    return stage

func _run() -> void:
    _cleanup_save()
    var stage := _world_with_road()
    var player := Node3D.new()
    player.position = Vector3(15.0, 0.0, 15.0)
    stage.add_child(player)
    var civic := Session.new()
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("could not start civic session")
        return
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var live := Live.new()
    stage.add_child(live)
    if not live.configure(stage, player, graph, civic):
        _fail("could not stage physical wrong-way vehicles")
        return
    var pending: Dictionary = live.snapshot()
    if not Live.checkpoint_valid(pending, graph, civic.snapshot()):
        _fail("valid early wrong-way state did not pass preflight")
        return
    var damaged: Dictionary = pending.duplicate(true)
    damaged["schema_version"] = 999
    if Live.checkpoint_valid(damaged, graph, civic.snapshot()):
        _fail("future wrong-way save schema was accepted")
        return
    damaged = pending.duplicate(true)
    damaged["followers"][0]["route_index"] = 99
    if Live.checkpoint_valid(damaged, graph, civic.snapshot()):
        _fail("out-of-bounds follower route was accepted")
        return
    damaged = pending.duplicate(true)
    damaged["reported_tick"] = pending["tick"]
    if Live.checkpoint_valid(damaged, graph, civic.snapshot()):
        _fail("unsolicited report without a mission record was accepted")
        return

    player.position = live.marker.global_position + Vector3(0, 0, 1.8)
    var has_queue: bool = false
    for frame in range(560):
        await physics_frame
        if live.stopped_count >= Live.REQUIRED_STOPPED:
            has_queue = true
            break
    if not has_queue:
        _fail("could not observe real queue before checkpoint")
        return
    if not live.perform_incident_action(player, "inspect") or not live.perform_incident_action(player, "report"):
        _fail("could not inspect and report before saving")
        return
    var saving := Lifecycle.new()
    stage.add_child(saving)
    if not saving.save_player(player, SAVE_PATH, {
        "civic_session": civic.snapshot(), "wrong_way_checkpoint": live.snapshot()
    }):
        _fail("mid-report checkpoint write failed")
        return
    var report_disk: Dictionary = SaveRepo.read_save(SAVE_PATH)
    if report_disk.is_empty() or not Live.checkpoint_valid(report_disk.get("wrong_way_checkpoint"), graph, report_disk.get("civic_session")):
        _fail("mid-report checkpoint did not round trip through JSON")
        return
    # Wait for a genuine marshal and for at least one metre of legal tow.
    var moving_tow: bool = false
    for frame in range(800):
        await physics_frame
        if live.tow_started and live.tow_progress_m > Live.OFFENDER_DISTANCE + Live.TOW_GAP_M + 1.0:
            moving_tow = true
            break
    if not moving_tow:
        _fail("authorized tow did not begin movement for the checkpoint test")
        return
    var saved_tow: Dictionary = live.snapshot()
    if not saving.save_player(player, SAVE_PATH, {
        "civic_session": civic.snapshot(), "wrong_way_checkpoint": saved_tow
    }):
        _fail("moving tow checkpoint write failed")
        return
    var loaded: Dictionary = SaveRepo.read_save(SAVE_PATH)
    if loaded.is_empty() or not Live.checkpoint_valid(loaded.get("wrong_way_checkpoint"), graph, loaded.get("civic_session")):
        _fail("moving tow JSON checkpoint preflight failed")
        return
    if not bool(loaded["wrong_way_checkpoint"]["tow_started"]):
        _fail("saved tow phase was lost on disk")
        return
    var saved_reward: int = civic.missions.claim_reward(Live.MISSION_ID)
    if saved_reward != 0:
        _fail("uncompleted wrong-way mission already paid a reward")
        return
    var original_mission_count: int = civic.missions.missions.size()
    stage.queue_free()
    await physics_frame
    await physics_frame

    var second_stage := _world_with_road()
    var next_player := Node3D.new()
    next_player.position = Vector3(15.0, 0.0, 15.0)
    second_stage.add_child(next_player)
    var next_civic := Session.new()
    second_stage.add_child(next_civic)
    if not next_civic.configure(second_stage, next_player):
        _fail("second civic session failed to start")
        return
    var next_live := Live.new()
    second_stage.add_child(next_live)
    if not next_live.prepare_restore(second_stage, next_player, graph, next_civic):
        _fail("new scene could not prepare real vehicle reconstruction")
        return
    if not next_civic.can_restore(loaded["civic_session"]) or not next_civic.restore(loaded["civic_session"]):
        _fail("saved civic incident/mission state not restored")
        return
    if not next_live.restore(loaded["wrong_way_checkpoint"]):
        _fail("real tow convoy did not restore from JSON")
        return
    if next_live.incident_id != int(saved_tow["incident_id"]) or next_live.tow_progress_m < float(saved_tow["tow_progress"]) - 0.01:
        _fail("tow state or incident ID changed on restore")
        return
    if next_civic.missions.missions.size() != original_mission_count:
        _fail("duplicate mission registered during scene reconstruction")
        return
    if next_live.perform_incident_action(next_player, "report"):
        _fail("a restored report could be submitted twice")
        return
    if next_civic.missions.claim_reward(Live.MISSION_ID) != 0:
        _fail("restored incomplete mission paid reward")
        return
    var completed: bool = false
    for frame in range(1100):
        await physics_frame
        if next_live.finished:
            completed = true
            break
    if not completed:
        _fail("restored physical tow convoy could not finish its mission")
        return
    if next_civic.metrics.scores["safety"] != 520 or next_civic.metrics.scores["efficiency"] != 530:
        _fail("restored mission applied incorrect or duplicate civic metrics")
        return
    if next_civic.missions.claim_reward(Live.MISSION_ID) != 0:
        _fail("restored completed mission reward could be claimed again")
        return
    var completed_json: Variant = JSON.parse_string(JSON.stringify(next_live.snapshot()))
    var validation_reasons: Array = []
    if not Live.checkpoint_valid(completed_json, graph, next_civic.snapshot(), validation_reasons):
        var summary: Dictionary = {
            "finished": next_live.finished,
            "tow_completed": next_live.tow_completed,
            "tow_progress": next_live.tow_progress_m,
            "incident_state": next_civic.incidents.incidents[next_live.incident_id]["state"],
            "mission_state": next_civic.missions.missions[Live.MISSION_ID]["state"],
            "reward_claimed": next_civic.missions.rewarded.has(Live.MISSION_ID),
            "peak_stopped": next_live.peak_stopped,
            "follower_states": completed_json.get("followers", [])
        }
        _fail("final restored checkpoint invalid: %s | %s" % [str(validation_reasons), JSON.stringify(summary)])
        return
    # Preserve strict terminal consistency: completed tow cannot be faked or
    # rewarded twice by changing boolean checkpoint fields.
    var forged: Dictionary = completed_json.duplicate(true)
    forged["tow_completed"] = false
    if Live.checkpoint_valid(forged, graph, next_civic.snapshot()):
        _fail("checkpoint accepted completed mission with unfinished tow")
        return
    forged = completed_json.duplicate(true)
    forged["finished"] = false
    if Live.checkpoint_valid(forged, graph, next_civic.snapshot()):
        _fail("checkpoint accepted completed mission with active gameplay flag")
        return
    # A legal completed route is exact after normalization, but older
    # floating-point saves may be a few millimetres past the endpoint.
    var tiny_drift: Dictionary = completed_json.duplicate(true)
    tiny_drift["tow_progress"] = float(tiny_drift["tow_progress"]) + 0.005
    if not Live.checkpoint_valid(tiny_drift, graph, next_civic.snapshot()):
        _fail("legitimate millimetre tow endpoint drift was refused")
        return
    var large_drift: Dictionary = completed_json.duplicate(true)
    large_drift["tow_progress"] = float(large_drift["tow_progress"]) + 0.5
    if Live.checkpoint_valid(large_drift, graph, next_civic.snapshot()):
        _fail("invalid tow overshoot passed numerical-tolerance check")
        return
    second_stage.queue_free()
    _cleanup_save()
    print("CIVIC_CHAOS_WRONG_WAY_CHECKPOINT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    _cleanup_save()
    quit(1)

## A generation-2 checkpoint keeps backup and temporary siblings. Isolate
## each test so an earlier run cannot be mistaken for a valid recovery.
func _cleanup_save() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        var candidate: String = SAVE_PATH + suffix
        if FileAccess.file_exists(candidate):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
