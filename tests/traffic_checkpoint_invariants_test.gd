extends SceneTree
## AUD-001: reject impossible traffic generations before staging physics bodies.
## Pure checkpoint validation: no actual cars, colliders or engine-step timing needed.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var spawner: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    if not spawner.configure(graph, 5252):
        _fail("test traffic graph rejected")
        return

    var valid: Dictionary = spawner.snapshot()
    valid["spawned_total"] = 1
    valid["cars"] = [{
        "route": [1, 4],
        "route_index": 0,
        "lane_distance": 2.0,
        "speed": 1.0,
        "target_speed": 5.0,
        "stop_requested": false,
        "obstacle_checks": false,
        "delay": 0.5,
        "profile": {
            "max_speed": 8.0, "acceleration": 3.0,
            "braking": 6.0, "turn_rate": 2.5, "vehicle_mask": 1
        }
    }]
    if not spawner.can_restore(valid):
        _fail("legitimate one-spawn/one-active checkpoint was rejected")
        return
    var original: Dictionary = spawner.snapshot()

    var impossible: Dictionary = valid.duplicate(true)
    impossible["completed_total"] = 1
    if spawner.can_restore(impossible):
        _fail("checkpoint claimed one completion and one active car from one spawn")
        return

    impossible = valid.duplicate(true)
    impossible["completed_total"] = 2
    if spawner.can_restore(impossible):
        _fail("checkpoint claimed more completed cars than spawned")
        return

    var final_lane: CivicLaneData = graph.get_lane(4)
    if final_lane == null:
        _fail("test final lane missing")
        return

    var ending: Dictionary = valid.duplicate(true)
    ending["cars"][0]["route_index"] = 1
    ending["cars"][0]["lane_distance"] = final_lane.length_m()
    ending["cars"][0]["speed"] = 0.0
    if spawner.can_restore(ending):
        _fail("active vehicle at its terminal endpoint was accepted and could stall forever")
        return

    ending["cars"][0]["lane_distance"] = final_lane.length_m() + 0.01
    if spawner.can_restore(ending):
        _fail("past-end terminal vehicle passed tolerance validation")
        return

    ending["cars"][0]["lane_distance"] = final_lane.length_m() - 0.01
    if not spawner.can_restore(ending):
        _fail("valid active car approaching destination was rejected")
        return

    if spawner.snapshot() != original or spawner.restore_prepared():
        _fail("pure checkpoint checks mutated live traffic or staged an actor")
        return

    spawner.advance_fixed(1, INF)
    if spawner.current_tick != 0:
        _fail("infinite fixed step advanced authoritative traffic time")
        return
    spawner.spawn_interval_ticks = 0
    spawner.advance_fixed(1, 0.05)
    if spawner.current_tick != 0:
        _fail("zero spawn interval advanced traffic into modulo-zero calculation")
        return
    spawner.spawn_interval_ticks = 30
    spawner.advance_fixed(1, 0.05)
    if spawner.current_tick != 1:
        _fail("valid tick did not advance after rejected steps")
        return

    spawner.free()
    print("CIVIC_CHAOS_TRAFFIC_CHECKPOINT_INVARIANTS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
