extends SceneTree
## TRAFFIC-PERF-11A: tow service may not run red or remove a real
## pedestrian; after two full cycles of measured lack of progress,
## authorized roadside collection is permitted ONLY at an empty worksite.
## The civic mission still requires two physical cars to resume.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.collision_layer = 1
    floor.collision_mask = 0
    floor.position.y = -0.25
    var box := BoxShape3D.new()
    box.size = Vector3(150, 0.5, 24)
    var collider := CollisionShape3D.new()
    collider.shape = box
    floor.add_child(collider)
    stage.add_child(floor)
    var player := Node3D.new()
    player.position = Vector3(15, 0, 15)
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic session setup failed")
        return
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    stage.add_child(spawner)
    if not spawner.configure(graph, 555, true):
        _fail("traffic spawner setup failed")
        return
    var signals := Signals.new()
    signals.enable_single_approach_mode()
    var reservations := Reservations.new()
    spawner.configure_intersection(signals, reservations)
    var live := Live.new() as CivicWrongWayLiveMission
    stage.add_child(live)
    if not live.configure(stage, player, graph, civic, spawner):
        _fail("mission staging failed")
        return
    live.set_physics_process(false)
    if not civic.incidents.transition(live.incident_id, CivicIncidentManager.ESCALATED, live.tick, "test_report"):
        _fail("authorized report rejected")
        return
    if not civic.incidents.transition(live.incident_id, CivicIncidentManager.INTERVENTION, live.tick, "test_marshal"):
        _fail("marshal intervention rejected")
        return
    live.reported_tick = live.tick
    live.intervention_tick = live.tick
    await physics_frame
    if not live._start_tow_convoy():
        _fail("authorized tow did not stage")
        return
    var lane: CivicLaneData = graph.get_lane(live.approach_lane_id)
    var approach: String = spawner.signal_approach_for_lane(lane, true)
    if approach != "W":
        _fail("west approach fixture changed: " + approach)
        return
    var stop_progress: float = lane.length_m() - 5.0
    live.tow_progress_m = stop_progress
    live.tow_vehicle.lane_distance_m = stop_progress
    live.tow_vehicle.global_transform = live._tow_pose(stop_progress, false)
    live.offender.global_transform = live._tow_pose(stop_progress - Live.TOW_GAP_M, true)
    live.offender_distance_m = stop_progress - Live.TOW_GAP_M
    await physics_frame
    var detail: Dictionary = live._tow_gate_snapshot()
    if detail.get("approach") != "W" or detail.get("aspect") != "red" or (
            float(detail.get("next_green_seconds", -1)) <= 0.0):
        _fail("service gate omitted actual incoming red direction / next green")
        return
    live._tow_stationary_seconds = Live.STARVATION_MIN_SECONDS - 1.0
    if live._tow_can_begin_starvation_recovery():
        _fail("one red wait incorrectly triggered emergency collection")
        return
    live._tow_stationary_seconds = Live.STARVATION_MIN_SECONDS + 1.0
    var pedestrian_id: int = 707
    var zone: String = "pedestrian_crossing_ew"
    if not bool(reservations.request(pedestrian_id,
            PackedStringArray([zone]), 0, 200).get("granted", false)) or (
            not reservations.occupy(pedestrian_id, zone)):
        _fail("pedestrian fixture failed")
        return
    if live._tow_can_begin_starvation_recovery():
        _fail("active crossing occupant was ignored by roadside collection")
        return
    reservations.release(pedestrian_id, zone)
    reservations.cancel(pedestrian_id)
    var person := StaticBody3D.new()
    person.collision_layer = 8
    person.collision_mask = 0
    person.position = live.tow_vehicle.global_position + Vector3.UP * 0.8
    var person_shape := CollisionShape3D.new()
    var person_box := BoxShape3D.new()
    person_box.size = Vector3(0.8, 1.6, 0.8)
    person_shape.shape = person_box
    person.add_child(person_shape)
    stage.add_child(person)
    await physics_frame
    if live._tow_can_begin_starvation_recovery():
        _fail("real pedestrian at service worksite was ignored")
        return
    person.queue_free()
    await physics_frame
    await physics_frame
    if not live._tow_can_begin_starvation_recovery():
        _fail("empty worksite could not release long-starved authorized tow")
        return
    if signals.aspect_for_approach(approach) != "red":
        _fail("test changed signal instead of arranging ground service")
        return
    live._advance_tow_convoy(0.05)
    if not live.service_recovery_active or live.blocker_removed or live.finished:
        _fail("service recovery skipped stationary collection or forged payout")
        return
    live._advance_ground_recovery(Live.SERVICE_RECOVERY_SECONDS)
    if not live.tow_completed or not live.blocker_removed or live.finished:
        _fail("roadside collection did not clear only offender / tow safely")
        return
    if civic.missions.claim_reward(Live.MISSION_ID) != 0:
        _fail("service recovery paid before followers had actually cleared")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_PERF_11A_TOW_STARVATION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
