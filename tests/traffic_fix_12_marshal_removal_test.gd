extends SceneTree
## TRAFFIC-FIX-12 — player-ordered local removal cannot precede evidence
## or marshal arrival, cannot work through a pedestrian, and cannot
## fabricate mission completion. It avoids the blocked tow travel entirely.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var player := Node3D.new()
    player.position = Vector3(15, 0, 15)
    world.add_child(player)
    var session := Session.new() as CivicGameplaySession
    world.add_child(session)
    if not session.configure(world, player):
        _fail("session configure failed")
        return
    var graph := Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    world.add_child(spawner)
    if not spawner.configure(graph, 121, true):
        _fail("traffic graph rejected")
        return
    var mission := Live.new() as CivicWrongWayLiveMission
    world.add_child(mission)
    if not mission.configure(world, player, graph, session, spawner):
        _fail("wrong-way mission staging failed")
        return
    mission.set_physics_process(false)
    if bool(mission.request_marshal_clearance().get("accepted", false)):
        _fail("unreported offence was cleared")
        return
    if not session.incidents.transition(mission.incident_id,
            CivicIncidentManager.ESCALATED, mission.tick, "verified_report"):
        _fail("reported incident failed")
        return
    mission.inspected = true
    mission.reported_tick = mission.tick
    if bool(mission.request_marshal_clearance().get("accepted", false)):
        _fail("offence cleared before authorized marshal arrived")
        return
    if not session.incidents.transition(mission.incident_id,
            CivicIncidentManager.INTERVENTION, mission.tick, "marshal_arrived"):
        _fail("intervention transition failed")
        return
    mission.intervention_tick = mission.tick
    mission._create_marshal()
    await physics_frame
    var stranger := StaticBody3D.new()
    stranger.collision_layer = 8
    stranger.collision_mask = 0
    stranger.position = mission.offender.global_position + Vector3.UP * 0.7
    var shape := CollisionShape3D.new()
    var body := BoxShape3D.new()
    body.size = Vector3(0.8, 1.4, 0.8)
    shape.shape = body
    stranger.add_child(shape)
    world.add_child(stranger)
    await physics_frame
    if bool(mission.request_marshal_clearance().get("accepted", false)):
        _fail("real pedestrian ignored at offender worksite")
        return
    stranger.queue_free()
    await physics_frame
    await physics_frame
    var request: Dictionary = mission.request_marshal_clearance()
    if not bool(request.get("accepted", false)):
        _fail("authorized marshal could not clear safe roadside: " + str(request))
        return
    if mission.blocker_removed or mission.finished:
        _fail("button instantly removed the car or paid the mission")
        return
    mission._advance_marshal_clearance(0.9)
    if mission.blocker_removed:
        _fail("car removed before secure worksite interval")
        return
    mission._advance_marshal_clearance(1.2)
    if not mission.blocker_removed or not mission.tow_completed or not mission.tow_recovered_on_site:
        _fail("marshal did not remove actual offender")
        return
    if mission.finished or mission.released_ids.size() != 0:
        _fail("marshal removal fabricated physical follower movement")
        return
    if not spawner.central_recovery_active():
        _fail("road reopening omitted actual follower discharge window")
        return
    var checkpoint: Dictionary = mission.snapshot()
    if not bool(checkpoint["tow_started"]) or not bool(checkpoint["tow_completed"]) or (
            not bool(checkpoint["blocker_removed"])):
        _fail("local removal cannot be checkpointed with canonical tow stage")
        return
    world.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_12_MARSHAL_REMOVAL_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
