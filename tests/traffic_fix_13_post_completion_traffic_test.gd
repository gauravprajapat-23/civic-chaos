extends SceneTree
## TRAFFIC-FIX-13 — Civic mission completion must never freeze its real
## follower cars in the street, even when the award is already committed.
## They remain physical until their actual graph routes complete.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")

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
        _fail("session setup failed")
        return
    var graph := Builder.make_city_graph()
    var mission := Live.new() as CivicWrongWayLiveMission
    world.add_child(mission)
    if not mission.configure(world, player, graph, session):
        _fail("mission staging failed")
        return
    if mission.followers.size() != 4:
        _fail("missing physical mission followers")
        return
    # Model an already-paid mission with its offending car lawfully
    # removed. No new reward/civic events should occur during clean-up.
    mission.finished = true
    mission.tow_completed = true
    mission.tow_started = true
    mission.blocker_removed = true
    mission.offender.queue_free()
    await physics_frame
    var initial: Array[float] = []
    for car in mission.followers:
        initial.append(car.lane_distance_m)
    for frame in range(120):
        mission._physics_process(0.05)
        await physics_frame
    var moved: int = 0
    for index in range(mission.followers.size()):
        var car: CivicVehicleAgent = mission.followers[index]
        if car.lane_distance_m > initial[index] + 0.5 or car.current_route_index > 0:
            moved += 1
    if moved < 2:
        _fail("mission already finished but its physical follower cars froze in the street")
        return
    # Route completion, not the civic payout, retires collision bodies.
    for frame in range(900):
        mission._physics_process(0.05)
        await physics_frame
        var active_count: int = 0
        for car in mission.followers:
            active_count += int(car.active)
        if active_count == 0:
            break
    var finished_cars: int = 0
    for car in mission.followers:
        if not car.active:
            finished_cars += 1
            var body: StaticBody3D = car.get_node("CollisionBody") as StaticBody3D
            if body.collision_layer != 0 or car.visible:
                _fail("completed mission car left an invisible solid obstacle")
                return
    if finished_cars < 2:
        _fail("completed mission cars did not finish physically traversing the road")
        return
    if not mission.finished:
        _fail("traffic cleanup reset civic mission completion")
        return
    world.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_13_POST_COMPLETION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
