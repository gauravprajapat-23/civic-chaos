extends SceneTree
## TRAFFIC-FIX-11C: an actual reported Wrong Way intervention
## activates central municipal admission metering, and finishing service
## restores ordinary traffic. A fabricated report cannot activate it.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Reservations = preload("res://scripts/traffic/intersection_reservations.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var ground := StaticBody3D.new()
    ground.collision_layer = 1
    ground.collision_mask = 0
    ground.position.y = -0.25
    var ground_shape := CollisionShape3D.new()
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(150, 0.5, 24)
    ground_shape.shape = ground_box
    ground.add_child(ground_shape)
    world.add_child(ground)
    var player := Node3D.new()
    player.position = Vector3(15, 0, 15)
    world.add_child(player)
    var session := Session.new() as CivicGameplaySession
    world.add_child(session)
    if not session.configure(world, player):
        _fail("session not configured")
        return
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    world.add_child(spawner)
    if not spawner.configure(graph, 22, true):
        _fail("spawner not configured")
        return
    var signals := Signals.new()
    signals.enable_single_approach_mode()
    spawner.configure_intersection(signals, Reservations.new())
    var mission := Live.new() as CivicWrongWayLiveMission
    world.add_child(mission)
    if not mission.configure(world, player, graph, session, spawner):
        _fail("mission actor staging failed")
        return
    mission.set_physics_process(false)
    if spawner.central_service_priority_active():
        _fail("service priority active before lawful report")
        return
    if mission._start_tow_convoy() or spawner.central_service_priority_active():
        _fail("unauthorized tow or priority was accepted")
        return
    if not session.incidents.transition(mission.incident_id,
            CivicIncidentManager.ESCALATED, mission.tick, "verified_report"):
        _fail("report transition rejected")
        return
    if not session.incidents.transition(mission.incident_id,
            CivicIncidentManager.INTERVENTION, mission.tick, "officer_arrived"):
        _fail("marshal transition rejected")
        return
    mission.reported_tick = mission.tick
    mission.intervention_tick = mission.tick
    await physics_frame
    if not mission._start_tow_convoy():
        _fail("authorized tow failed to start")
        return
    if not spawner.central_service_priority_active():
        _fail("mission failed to reserve protected service window")
        return
    var incoming: CivicVehicleAgent = mission.tow_vehicle
    if not is_instance_valid(incoming):
        _fail("missing tow vehicle")
        return
    mission._tow_stationary_seconds = 3.0
    mission._record_tow_stalled_frame(0.05, "red_signal")
    mission._record_tow_stalled_frame(0.05, "tow-truck route physically occupied")
    mission._record_tow_stalled_frame(0.05, "pedestrian_crossing")
    if mission._tow_stationary_seconds < 3.14 or mission.service_recovery_active:
        _fail("alternating real hold reasons lost progress time or forged recovery")
        return
    mission.tow_recovered_on_site = true
    mission._finish_tow_convoy()
    if not mission.tow_completed or not mission.blocker_removed:
        _fail("authorized stationary recovery did not clear incident")
        return
    if spawner.central_service_priority_active():
        _fail("mission priority not released after tow completion")
        return
    if mission.finished or mission.released_ids.size() > 0:
        _fail("follower traffic reward fabricated by tow removal")
        return
    world.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_11C_TOW_PRIORITY_LIFECYCLE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
