extends SceneTree
## GAME-012 — actual scene vehicles queue, real marshal and observed recovery.
## No synthetic demand values or mock queue counters.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.name = "RoadSupport"
    floor.position = Vector3(0.0, -0.25, 0.0)
    floor.collision_layer = 1
    floor.collision_mask = 0
    var floor_shape := CollisionShape3D.new()
    floor_shape.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(140, 0.5, 24)
    floor_shape.shape = box
    floor.add_child(floor_shape)
    stage.add_child(floor)
    var player := Node3D.new()
    player.name = "PlayerRoot"
    player.position = Vector3(15, 0, 15)
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic session not configured")
        return
    var live := Live.new() as CivicWrongWayLiveMission
    stage.add_child(live)
    if not live.configure(stage, player, Builder.make_city_graph(), civic):
        _fail("live wrong-way scenario could not stage real vehicles")
        return
    if live.approach_lane_id < 100 or live.exit_lane_id < 100 or live.followers.size() < 3:
        _fail("incident not bound to real expanded city route and vehicle scenes")
        return
    var lane: CivicLaneData = live.city_graph.get_lane(live.approach_lane_id)
    var tangent: Vector3 = CivicVehicleAgent.sample_centerline(lane.centerline, 28.0)["tangent"]
    var wrong_forward: Vector3 = -live.offender.global_transform.basis.z
    if wrong_forward.dot(tangent) > -0.8:
        _fail("wrong-way offender is not facing against traffic")
        return
    if civic.missions.missions[Live.MISSION_ID]["progress"]["congestion_observed"] != 0:
        _fail("mission manufactured congestion before cars moved")
        return

    player.position = live.marker.global_position + Vector3(0, 0, 1.8)
    if live.perform_incident_action(player, "report"):
        _fail("report accepted without observation")
        return
    if live.perform_incident_action(player, "inspect"):
        _fail("inspection accepted before a real traffic queue formed")
        return
    var queue_formed: bool = false
    for frame in range(540):
        await physics_frame
        if live.stopped_count >= Live.REQUIRED_STOPPED:
            queue_formed = true
            break
    if not queue_formed:
        var summary: Array[String] = []
        for car in live.followers:
            summary.append("%.2fm/%.2fmps" % [car.lane_distance_m, car.speed_mps])
        _fail("actual follower queue did not form; positions/speeds: " + ", ".join(summary))
        return
    if live.peak_stopped < 2 or live.released_ids.size() != 0:
        _fail("queue telemetry inconsistent before intervention")
        return
    # The physical evidence point must expose the same card on E/USE; a
    # remote interaction may not open it or bypass action authorization.
    var card_requests: Array[Dictionary] = []
    live.incident_card_requested.connect(func(state: Dictionary) -> void:
        card_requests.append(state)
    )
    player.global_position = Vector3(25, 0, 25)
    live.marker.interact(player)
    if not card_requests.is_empty():
        _fail("distant player opened wrong-way evidence")
        return
    player.global_position = live.marker.global_position + Vector3(0, 0, 1.8)
    live.marker.interact(player)
    if card_requests.size() != 1 or not bool(card_requests[0].get("can_inspect", false)):
        _fail("nearby E/USE did not open a truthful wrong-way evidence card")
        return
    var actual_stopped: int = 0
    for car in live.followers:
        if car.active and live.moved_ids.has(car.get_instance_id()) and car.speed_mps < 0.35:
            actual_stopped += 1
    if actual_stopped != live.stopped_count:
        _fail("reported queue differs from physical vehicle state")
        return
    if not live.perform_incident_action(player, "inspect"):
        _fail("player failed to inspect observed congestion")
        return
    if not live.perform_incident_action(player, "report"):
        _fail("authorized player report was denied")
        return
    if live.perform_incident_action(player, "report"):
        _fail("duplicate civic report accepted")
        return
    if live.intervention_tick >= 0:
        _fail("marshal intervention started before physical response")
        return
    for frame in range(200):
        await physics_frame
        if live.intervention_tick >= 0:
            break
    if live.intervention_tick < 0 or not is_instance_valid(live.marshal):
        _fail("visible marshal did not reach the scene")
        return
    if civic.missions.missions[Live.MISSION_ID]["progress"]["marshal_intervened"] != 1:
        _fail("marshal arrival did not advance mission")
        return
    var released: bool = false
    var observed_tow: bool = false
    var last_towed_position: Vector3 = live.offender.global_position
    var max_towed_step: float = Live.TOW_SPEED_MPS * (1.0 / float(Engine.physics_ticks_per_second)) + 0.22
    for frame in range(1100):
        await physics_frame
        if live.tow_started:
            observed_tow = true
            if not live.tow_completed:
                if not is_instance_valid(live.tow_vehicle) or not is_instance_valid(live.offender):
                    _fail("escort lost a vehicle before it reached its legal exit")
                    return
                var travel_step: float = live.offender.global_position.distance_to(last_towed_position)
                if travel_step > max_towed_step:
                    _fail("towed offender teleported %.2fm between physics frames" % travel_step)
                    return
                if live.blocker_removed:
                    _fail("obstruction was declared removed while tow truck was still on road")
                    return
                if not live.city_graph.outgoing_legal_lanes(live.approach_lane_id, 1).has(live.exit_lane_id):
                    _fail("tow convoy did not use a legal route")
                    return
        if is_instance_valid(live.offender):
            last_towed_position = live.offender.global_position
        if live.finished:
            released = true
            break
    if not observed_tow or not live.tow_completed:
        _fail("visible tow convoy did not complete its authorized route")
        return
    if not released:
        var cars: Array[String] = []
        for car in live.followers:
            cars.append("lane%d %.1fm/%.1fmps" % [car.current_route_index, car.lane_distance_m, car.speed_mps])
        _fail("real traffic failed to recover; released=%d queue=%d cars=%s" % [live.released_ids.size(), live.stopped_count, ", ".join(cars)])
        return
    if is_instance_valid(live.offender) or is_instance_valid(live.tow_vehicle) or not live.blocker_removed:
        _fail("tow convoy did not clear the actual vehicles from the legal exit")
        return
    if live.released_ids.size() < Live.REQUIRED_RELEASED:
        _fail("mission completed without actual moving vehicles passing blockage")
        return
    var remaining_stopped: int = 0
    for car in live.followers:
        if car.active and car.current_route_index == 0 and live.moved_ids.has(car.get_instance_id()) and car.speed_mps < 0.35:
            remaining_stopped += 1
    if remaining_stopped != live.stopped_count:
        _fail("queue telemetry was artificially cleared after offender removal")
        return
    if civic.incidents.incidents[live.incident_id]["state"] != CivicIncidentManager.RESOLVED:
        _fail("wrong-way incident not resolved")
        return
    if civic.missions.missions[Live.MISSION_ID]["state"] != CivicMissionManager.COMPLETED:
        _fail("wrong-way civic mission not completed")
        return
    if civic.missions.claim_reward(Live.MISSION_ID) != 0:
        _fail("wrong-way civic reward duplicated")
        return
    if civic.metrics.scores["safety"] != 520 or civic.metrics.scores["efficiency"] != 530:
        _fail("civic outcomes not applied exactly once")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_WRONG_WAY_LIVE_MISSION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
