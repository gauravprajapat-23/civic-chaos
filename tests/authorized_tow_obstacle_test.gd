extends SceneTree
## GAME-013 — a municipal tow convoy must stop for a real world obstacle
## and resume only after the obstruction is physically cleared.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var support := StaticBody3D.new()
    support.collision_layer = 1
    support.collision_mask = 0
    support.position = Vector3(0, -0.25, 0)
    var ground_shape := CollisionShape3D.new()
    ground_shape.name = "CollisionShape3D"
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(150, 0.5, 24)
    ground_shape.shape = ground_box
    support.add_child(ground_shape)
    world.add_child(support)
    var player := Node3D.new()
    player.position = Vector3(15, 0, 15)
    world.add_child(player)
    var civic := Session.new()
    world.add_child(civic)
    if not civic.configure(world, player):
        _fail("failed to prepare civic world")
        return
    var live := Live.new()
    world.add_child(live)
    if not live.configure(world, player, Builder.make_city_graph(), civic):
        _fail("failed to stage wrong-way incident")
        return
    live.set_physics_process(false)
    if not civic.incidents.transition(live.incident_id, CivicIncidentManager.ESCALATED, live.tick, "test_report"):
        _fail("could not record authorized report")
        return
    if not civic.incidents.transition(live.incident_id, CivicIncidentManager.INTERVENTION, live.tick, "test_marshal"):
        _fail("could not record marshal intervention")
        return
    live.reported_tick = live.tick
    live.intervention_tick = live.tick
    await physics_frame
    if not live._start_tow_convoy():
        _fail("authorized tow truck could not stage in a clear road")
        return
    var blocked_progress: float = Live.OFFENDER_DISTANCE + Live.TOW_GAP_M + 8.0
    var obstruction := StaticBody3D.new()
    obstruction.name = "RoadObstruction"
    obstruction.collision_layer = 1
    obstruction.collision_mask = 0
    obstruction.position = live._tow_pose(blocked_progress, false).origin + Vector3.UP * 1.0
    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var block_shape := BoxShape3D.new()
    block_shape.size = Vector3(1.8, 2.0, 1.8)
    collision.shape = block_shape
    obstruction.add_child(collision)
    world.add_child(obstruction)
    await physics_frame
    for frame in range(150):
        live._advance_tow_convoy(1.0 / 60.0)
        await physics_frame
        if live.tow_progress_m >= blocked_progress - 2.4:
            _fail("municipal tow vehicle entered occupied world geometry")
            return
        if live.blocker_removed:
            _fail("mission marked the road clear despite a trapped tow")
            return
    var stopped_progress: float = live.tow_progress_m
    if stopped_progress < Live.OFFENDER_DISTANCE + Live.TOW_GAP_M + 1.0:
        _fail("tow vehicle never moved before reaching obstacle")
        return
    obstruction.queue_free()
    await physics_frame
    await physics_frame
    for frame in range(70):
        live._advance_tow_convoy(1.0 / 60.0)
        await physics_frame
        if live.tow_progress_m >= stopped_progress + 2.0:
            break
    if live.tow_progress_m < stopped_progress + 2.0:
        _fail("tow truck failed to resume after obstruction cleared")
        return
    if not live.tow_started or live.tow_completed:
        _fail("tow state changed before legal exit was reached")
        return
    world.queue_free()
    print("CIVIC_CHAOS_AUTHORIZED_TOW_OBSTACLE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
