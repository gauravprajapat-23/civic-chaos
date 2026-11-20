extends SceneTree
## WORLD-001C: municipal services obey the same priority/yield and
## downstream capacity policy as civilian traffic at an outer T-node.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Adapter = preload("res://scripts/traffic/responder_step_permission.gd")
var failures: int = 0

func _check(ok: bool, why: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-001C-RESPONDER: " + why)

func _point(lane: CivicLaneData, distance: float) -> Vector3:
    var rest: float = distance
    for i in range(1, lane.centerline.size()):
        var a: Vector3 = lane.centerline[i - 1]
        var b: Vector3 = lane.centerline[i]
        var segment: float = a.distance_to(b)
        if rest <= segment:
            return a.lerp(b, clampf(rest / maxf(segment, 0.0001), 0.0, 1.0))
        rest -= segment
    return lane.centerline[-1]

func _car(lane: CivicLaneData, distance: float) -> CivicVehicleAgent:
    var car := CivicVehicleAgent.new()
    car.active = true
    car.route = PackedInt32Array([lane.lane_id])
    car.lane_distance_m = distance
    return car

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var side: CivicLaneData = graph.get_lane(105)
    var through: CivicLaneData = graph.get_lane(102)
    var exit_lane: CivicLaneData = graph.get_lane(106)
    _check(side != null and through != null and exit_lane != null,
        "pilot network missing traffic lanes")
    if side == null or through == null or exit_lane == null:
        quit(1)
        return
    var spawner := Spawner.new() as CivicTrafficSpawner
    _check(spawner.configure(graph, 4201, true), "spawner rejected graph")
    var gate := Adapter.new() as CivicResponderStepPermission
    _check(gate.configure(spawner), "responder adapter unconfigured")
    var route := PackedInt32Array([105, 106])
    var before: float = side.length_m() - 6.5
    _check(gate.set_route_context(route, 0, before),
        "legal T-junction responder route not accepted")
    var start: Vector3 = _point(side, before)
    var finish: Vector3 = _point(side, before + 0.7)
    var collector: CivicVehicleAgent = _car(through, through.length_m() - 6.0)
    spawner.register_road_user(collector)
    _check(not gate.allows_step(start, finish),
        "responder ignored legal through traffic at give-way sign")
    spawner.unregister_road_user(collector)
    collector.free()
    _check(gate.allows_step(start, finish),
        "clear give-way intersection stranded responder")

    var blocked_exit: CivicVehicleAgent = _car(exit_lane, 1.0)
    spawner.register_road_user(blocked_exit)
    _check(not gate.allows_step(start, finish),
        "responder entered blocked downstream lane")
    spawner.unregister_road_user(blocked_exit)
    blocked_exit.free()
    _check(gate.allows_step(start, finish),
        "responder did not resume after exit cleared")
    gate.clear_context()
    _check(not gate.allows_step(start, finish),
        "cleared responder context still authorized crossing")
    spawner.free()
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_001C_RESPONDER_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_001C_RESPONDER_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
