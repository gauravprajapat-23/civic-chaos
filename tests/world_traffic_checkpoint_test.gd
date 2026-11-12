extends SceneTree
## GAME-019: fixed-step clock + signal + physical background-car snapshot.
const Clock = preload("res://scripts/core/simulation_clock.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var clock := Clock.new(20)
    if clock.advance(0.16) != 3:
        _fail("fixed step did not reach expected logical tick")
        return
    var data: Variant = JSON.parse_string(JSON.stringify(clock.snapshot()))
    var next_clock := Clock.new(20)
    if not next_clock.restore(data) or next_clock.tick_index != 3:
        _fail("clock lost fixed tick on JSON restore")
        return
    if next_clock.advance(0.04) != 1 or next_clock.tick_index != 4:
        _fail("clock accumulator was not restored")
        return
    var bad_clock: Dictionary = (data as Dictionary).duplicate(true)
    bad_clock["accumulator"] = 10.0
    if next_clock.restore(bad_clock):
        _fail("invalid clock accumulator accepted")
        return

    var light := Signals.new(4.0, 2.0, 1.0)
    light.advance_fixed(5.0)
    var signal_data: Variant = JSON.parse_string(JSON.stringify(light.snapshot()))
    var next_light := Signals.new(4.0, 2.0, 1.0)
    if not next_light.restore(signal_data) or next_light.phase_name() != "NS_AMBER":
        _fail("yellow phase was lost during restore")
        return
    if absf(next_light.phase_elapsed - 1.0) > 0.001 or next_light.aspect_for_approach("E") != "red":
        _fail("restored yellow phase timing or conflict changed")
        return
    var bad_signal: Dictionary = (signal_data as Dictionary).duplicate(true)
    bad_signal["phase"] = 77
    if next_light.restore(bad_signal):
        _fail("impossible signal phase accepted")
        return
    bad_signal = (signal_data as Dictionary).duplicate(true)
    bad_signal["phase_elapsed"] = 5.0
    if next_light.restore(bad_signal):
        _fail("signal elapsed beyond phase duration accepted")
        return
    next_light.advance_fixed(1.0)
    if next_light.phase_name() != "ALL_RED_NS":
        _fail("resumed signal skipped its all-red clearance")
        return

    var graph: CivicRoadGraph = Builder.make_test_graph()
    var stage := Node3D.new()
    root.add_child(stage)
    var first := Spawner.new()
    stage.add_child(first)
    first.spawn_interval_ticks = 8
    if not first.configure(graph, 3411):
        _fail("background traffic could not configure")
        return
    for tick in range(1, 90):
        first.advance_fixed(tick, 0.05)
    if first.active_vehicles.is_empty():
        _fail("no real cars available for checkpoint test")
        return
    var saved: Variant = JSON.parse_string(JSON.stringify(first.snapshot()))
    if not first.can_restore(saved):
        _fail("legitimate background traffic snapshot invalid")
        return
    var modified: Dictionary = (saved as Dictionary).duplicate(true)
    modified["cars"][0]["route_index"] = 50
    if first.can_restore(modified):
        _fail("forged car route index accepted")
        return
    modified = (saved as Dictionary).duplicate(true)
    modified["cars"][0]["speed"] = -12.0
    if first.can_restore(modified):
        _fail("forged negative car velocity accepted")
        return

    # A real physical collider at the intended resumed position must block
    # restoration without deleting the original traffic generation.
    var blocked := StaticBody3D.new()
    blocked.collision_layer = 4
    blocked.collision_mask = 0
    blocked.position = first.active_vehicles[0].global_position + Vector3.UP * 0.9
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = Vector3(1.2, 1.8, 1.2)
    shape.shape = box
    blocked.add_child(shape)
    stage.add_child(blocked)
    await physics_frame
    var count_before: int = first.active_vehicles.size()
    if first.restore(saved) or first.active_vehicles.size() != count_before:
        _fail("unsafe car restore deleted original traffic or crossed obstacle")
        return
    blocked.queue_free()
    await physics_frame
    await physics_frame

    # Rebuild into a clean SceneTree just as a fresh launch does.
    stage.queue_free()
    await physics_frame
    await physics_frame
    var resumed_stage := Node3D.new()
    root.add_child(resumed_stage)
    var resumed := Spawner.new()
    resumed_stage.add_child(resumed)
    resumed.spawn_interval_ticks = 8
    if not resumed.configure(graph, 3411):
        _fail("fresh traffic spawner could not configure")
        return
    if not resumed.can_restore(saved):
        _fail("JSON traffic generation rejected by semantic preflight: " + JSON.stringify(saved))
        return
    if not resumed.restore(saved):
        # The semantic checkpoint may be valid while its physical positions
        # conflict with real collision bodies. Report the car positions and
        # separation before deciding whether to change collision semantics.
        var placements: Array[String] = []
        var min_gap: float = INF
        for i in range(saved["cars"].size()):
            var item: Dictionary = saved["cars"][i]
            var lane_id: int = int(item["route"][int(item["route_index"])])
            var lane: CivicLaneData = graph.get_lane(lane_id)
            var sampled: Dictionary = CivicVehicleAgent.sample_centerline(lane.centerline, float(item["lane_distance"]))
            var pos: Vector3 = sampled["position"]
            placements.append("%d:lane=%d,distance=%.3f,pos=%s" % [i, lane_id, float(item["lane_distance"]), str(pos)])
            for j in range(i):
                var prior: Dictionary = saved["cars"][j]
                var other_lane: CivicLaneData = graph.get_lane(int(prior["route"][int(prior["route_index"])]))
                var other_pos: Vector3 = CivicVehicleAgent.sample_centerline(other_lane.centerline, float(prior["lane_distance"]))["position"]
                min_gap = minf(min_gap, pos.distance_to(other_pos))
        _fail("background traffic physical restoration rejected: min_car_spacing=%.3f cars=%s" % [min_gap, "; ".join(placements)])
        return
    var round_trip: Dictionary = resumed.snapshot()
    if round_trip["rng_state"] != saved["rng_state"] or round_trip["current_tick"] != saved["current_tick"] or round_trip["spawned_total"] != saved["spawned_total"]:
        _fail("traffic generation, counters or RNG state changed on restore")
        return
    if round_trip["cars"].size() != saved["cars"].size():
        _fail("restored traffic generation has missing or duplicate cars")
        return
    for index in range(round_trip["cars"].size()):
        var actual: Dictionary = round_trip["cars"][index]
        var expected: Dictionary = saved["cars"][index]
        if actual["route"] != expected["route"] or actual["route_index"] != expected["route_index"] or absf(float(actual["lane_distance"]) - float(expected["lane_distance"])) > 0.001:
            _fail("restored car lost its route or physical lane position")
            return
    if resumed.rng.state != int((saved as Dictionary)["rng_state"]):
        _fail("RNG state did not survive JSON's integer limitations")
        return
    resumed_stage.queue_free()
    print("CIVIC_CHAOS_WORLD_TRAFFIC_CHECKPOINT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
