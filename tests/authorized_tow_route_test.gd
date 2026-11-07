extends SceneTree
## GAME-013 — Verify legal tow geometry and authorization without hiding
## bad simulation state behind a synthetic congestion counter.
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
    var civic := Session.new()
    world.add_child(civic)
    if not civic.configure(world, player):
        _fail("civic tutorial not configured")
        return
    var mission := Live.new()
    world.add_child(mission)
    var graph: CivicRoadGraph = Builder.make_city_graph()
    if not mission.configure(world, player, graph, civic):
        _fail("wrong-way vehicles could not stage on city graph")
        return
    mission.set_physics_process(false)
    if mission._start_tow_convoy():
        _fail("unauthorized tow convoy started without a report or marshal")
        return
    var legal_exits: Array[int] = graph.outgoing_legal_lanes(mission.approach_lane_id, 1)
    if not legal_exits.has(mission.exit_lane_id):
        _fail("tow destination not connected as legal road")
        return
    var inbound: CivicLaneData = graph.get_lane(mission.approach_lane_id)
    var length: float = inbound.length_m()
    var start: Transform3D = mission._tow_pose(Live.OFFENDER_DISTANCE, false)
    var backward: Transform3D = mission._tow_pose(Live.OFFENDER_DISTANCE, true)
    if (-start.basis.z).dot(-backward.basis.z) > -0.99:
        _fail("towed offender no longer faces opposite the legal travel direction")
        return
    var last_pose: Transform3D = mission._tow_pose(length - 0.25, false)
    var after_joint: Transform3D = mission._tow_pose(length + 0.25, false)
    if last_pose.origin.distance_to(after_joint.origin) > 0.51:
        _fail("legal tow lane connection has a position teleport")
        return
    var end_pose: Transform3D = mission._tow_pose(mission._tow_route_length(), false)
    if end_pose.origin.distance_to(Vector3(46, 0, 0)) > 0.1:
        _fail("tow does not exit through approved eastbound lane")
        return
    world.queue_free()
    print("CIVIC_CHAOS_AUTHORIZED_TOW_ROUTE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
