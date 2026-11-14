extends SceneTree
## AUD3: a gridlocked downstream tow route must not trap mission forever.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.position.y = -0.25
    floor.collision_layer = 1
    floor.collision_mask = 0
    var shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(140, 0.5, 24)
    shape.shape = floor_box
    floor.add_child(shape)
    stage.add_child(floor)
    var actor := Node3D.new()
    actor.position = Vector3(15, 0, 15)
    stage.add_child(actor)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, actor):
        _fail("session failed")
        return
    var live := Live.new() as CivicWrongWayLiveMission
    stage.add_child(live)
    if not live.configure(stage, actor, Builder.make_city_graph(), civic):
        _fail("mission staging failed")
        return
    actor.position = live.marker.global_position + Vector3(0, 0, 1.8)
    var queued := false
    for i in range(600):
        await physics_frame
        if live.stopped_count >= Live.REQUIRED_STOPPED:
            queued = true
            break
    if not queued or not live.perform_incident_action(actor, "inspect") or not live.perform_incident_action(actor, "report"):
        _fail("could not report real blocked traffic")
        return
    var towing := false
    for i in range(600):
        await physics_frame
        if live.tow_started:
            towing = true
            break
    if not towing:
        _fail("municipal tow did not begin")
        return
    # Reproduce a persistent obstruction in the outgoing route without
    # changing collision layers or teleporting mission cars.
    var obstacle := StaticBody3D.new()
    obstacle.collision_layer = 4
    obstacle.collision_mask = 0
    var collider := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.8, 1.3, 3.2)
    collider.shape = box
    collider.position.y = 0.7
    obstacle.add_child(collider)
    stage.add_child(obstacle)
    obstacle.global_position = live._tow_pose(live.tow_progress_m + 4.0, false).origin
    # Advance until the convoy physically encounters the obstacle and lift
    # recovery activates; do not inject success flags or arbitrary rewards.
    var observed_lift := false
    for i in range(650):
        await physics_frame
        if live.service_lift_height_m > 0.0:
            observed_lift = true
            break
    if not observed_lift:
        _fail("congestion did not activate on-site recovery")
        return
    var snap: Dictionary = live.snapshot()
    if not Live.checkpoint_valid(snap, live.city_graph, civic.snapshot()):
        _fail("active recovery not checkpoint-valid")
        return
    for i in range(220):
        await physics_frame
        if live.tow_completed:
            break
    if not live.tow_completed or not live.tow_recovered_on_site or not live.blocker_removed:
        _fail("municipal recovery did not remove obstruction after visible lift")
        return
    if live.finished:
        _fail("mission awarded completion without two cars clearing")
        return
    obstacle.queue_free()
    for i in range(950):
        await physics_frame
        if live.finished:
            break
    if not live.finished or live.released_ids.size() < Live.REQUIRED_RELEASED:
        _fail("queued real vehicles did not recover after service removal")
        return
    if civic.missions.claim_reward(Live.MISSION_ID) != 0:
        _fail("recovery mission paid duplicate reward")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_AUD3_TOW_GRIDLOCK_RECOVERY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
