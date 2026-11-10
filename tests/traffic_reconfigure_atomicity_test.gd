extends SceneTree
## AUD-001: a rejected traffic reconfiguration cannot destroy a running fleet,
## change its seed/counters, or abort a prepared save restore.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var spawner: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    stage.add_child(spawner)
    if not spawner.configure(graph, 4455):
        _fail("initial four-arm traffic setup was rejected")
        return
    if spawner.normal_entry_lanes != PackedInt32Array([1, 3, 5, 7]):
        _fail("valid four-arm graph lost its legal traffic entrances")
        return
    var initial: Dictionary = spawner.snapshot()
    # Seed work from the old generation. A rejected reconfiguration must
    # preserve this state alongside the live fleet and prepared restore.
    spawner.work_budget.update_sensor(222, {"gap": 3.0})
    spawner.work_budget.record_duration_us(17)
    spawner.work_budget.select_decisions(50, PackedInt32Array([222]))
    if not spawner.prepare_restore(initial) or not spawner.restore_prepared():
        _fail("could not prepare empty-generation checkpoint")
        return
    # A four-arm 20m test graph has no +/-120m city perimeter entrance.
    if spawner.configure(graph, 9999, true):
        _fail("expanded city wrongly accepted a graph without perimeter entries")
        return
    if not spawner.restore_prepared() or spawner.snapshot() != initial or spawner.road_graph != graph:
        _fail("rejected reconfiguration aborted the pending checkpoint or mutated traffic")
        return
    if spawner.work_budget.cached_sensor(222).get("gap", -1.0) != 3.0 or spawner.work_budget.metrics()["sample_count"] != 1:
        _fail("rejected reconfiguration cleared the running work budget")
        return
    if not spawner.work_budget.select_decisions(1, PackedInt32Array([222])).is_empty():
        _fail("rejected reconfiguration reset the running generation's tick cursor")
        return
    spawner.abort_restore()
    if spawner.restore_prepared():
        _fail("explicit abort failed after rejected reconfiguration")
        return

    await physics_frame
    if not spawner.try_spawn() or spawner.active_vehicles.size() != 1:
        _fail("could not seed a physical vehicle for reconfiguration test")
        return
    var original_vehicle: CivicVehicleAgent = spawner.active_vehicles[0]
    var before: Dictionary = spawner.snapshot()

    # A topologically valid graph can lack the legacy entry IDs entirely.
    # Refuse that configuration before deleting existing cars and counters.
    var no_entrances := CivicRoadGraph.new()
    var isolated_lane := CivicLaneData.new()
    isolated_lane.lane_id = 90
    isolated_lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -12)])
    if not no_entrances.add_lane(isolated_lane) or not no_entrances.validate().is_empty():
        _fail("single legal standalone lane fixture was incorrectly invalid")
        return
    if spawner.configure(no_entrances, 9999):
        _fail("graph without a spawnable legacy entry replaced active traffic")
        return
    if spawner.active_vehicles[0] != original_vehicle or spawner.snapshot() != before:
        _fail("unspawnable graph discarded the previous traffic generation")
        return
    if spawner.configure(graph, 9999, true):
        _fail("invalid city graph accepted while live vehicle exists")
        return
    if not is_instance_valid(original_vehicle) or spawner.active_vehicles.size() != 1 or spawner.active_vehicles[0] != original_vehicle:
        _fail("rejected city reconfiguration discarded the running vehicle")
        return
    if spawner.snapshot() != before or spawner.road_graph != graph or spawner.city_mode:
        _fail("rejected city reconfiguration changed counters, RNG, graph or mode")
        return

    spawner.spawn_interval_ticks = 0
    if spawner.configure(graph, 9999):
        _fail("zero spawn interval accepted for a running fleet")
        return
    spawner.spawn_interval_ticks = 30
    spawner.spawn_clearance_m = INF
    if spawner.configure(graph, 9999):
        _fail("nonfinite spawn clearance accepted")
        return
    spawner.spawn_clearance_m = 5.0
    if spawner.snapshot() != before or spawner.active_vehicles[0] != original_vehicle:
        _fail("bad configuration mutated the traffic generation")
        return

    if not spawner.configure(graph, 6789):
        _fail("valid replacement graph could not be configured")
        return
    if not spawner.active_vehicles.is_empty() or spawner.seed != 6789 or spawner.spawned_total != 0 or spawner.city_mode:
        _fail("successful reconfiguration failed to reset traffic generation")
        return
    if not spawner.city_entry_lanes.is_empty() or spawner.restore_prepared():
        _fail("successful reconfiguration retained stale city entrances or restore state")
        return
    if spawner.normal_entry_lanes != PackedInt32Array([1, 3, 5, 7]):
        _fail("normal reconfiguration did not restore the valid entry pool")
        return
    if not spawner.work_budget.cached_sensor(222).is_empty() or spawner.work_budget.metrics()["sample_count"] != 0:
        _fail("accepted reconfiguration retained obsolete cache or performance samples")
        return
    if spawner.work_budget.select_decisions(1, PackedInt32Array([11, 22])) != PackedInt32Array([11, 22]):
        _fail("new generation inherited an old traffic decision clock")
        return

    # A checkpoint COMMIT is another generation replacement. Check that it
    # retires the scheduler from later ticks, without changing the snapshot.
    var committed_snapshot: Dictionary = spawner.snapshot()
    spawner.work_budget.update_sensor(11, {"gap": 0.5})
    spawner.work_budget.record_duration_us(99)
    spawner.work_budget.select_decisions(900, PackedInt32Array([11, 22]))
    if not spawner.prepare_restore(committed_snapshot) or not spawner.commit_restore():
        _fail("valid checkpoint commit was rejected during budget reset test")
        return
    if not spawner.work_budget.cached_sensor(11).is_empty() or spawner.work_budget.metrics()["sample_count"] != 0:
        _fail("committed checkpoint retained previous generation sensor or timings")
        return
    if spawner.work_budget.select_decisions(1, PackedInt32Array([11, 22])) != PackedInt32Array([11, 22]):
        _fail("committed checkpoint kept a future work-budget tick")
        return
    # A successful configuration is allowed to invalidate a prepared
    # checkpoint, unlike a rejected configuration.
    var fresh: Dictionary = spawner.snapshot()
    if not spawner.prepare_restore(fresh):
        _fail("could not prepare a checkpoint after successful reset")
        return
    if not spawner.configure(graph, 7001) or spawner.restore_prepared() or spawner.seed != 7001:
        _fail("accepted reconfiguration failed to retire the old checkpoint")
        return
    await physics_frame
    if is_instance_valid(original_vehicle):
        _fail("superseded vehicle collider survived the successful reconfiguration")
        return

    # Some canonical entrances can be legal geometry yet have no exits.
    # Filter only those entrance IDs; keep the remaining traffic playable.
    var partial := Builder.make_test_graph()
    partial.get_lane(1).next_lane_ids = PackedInt32Array()
    if not spawner.configure(partial, 7022):
        _fail("partially disconnected graph was incorrectly rejected")
        return
    if spawner.normal_entry_lanes != PackedInt32Array([3, 5, 7]):
        _fail("spawner still selects legal entrance 1 with no outbound route")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_RECONFIGURE_ATOMICITY_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
