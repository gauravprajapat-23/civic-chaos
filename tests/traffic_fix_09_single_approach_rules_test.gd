extends SceneTree
## TRAFFIC-FIX-09 — a real playable central four-way junction is strictly
## one-green-at-a-time. NPC vehicles obey their particular approach,
## walkers cannot cross against the opposing direction, legacy signals
## and JSON checkpoint compatibility remain supported.
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var signals := Signals.new(12.0, 3.0, 2.0)
    signals.enable_single_approach_mode()
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 333, true):
        _fail("expanded city graph failed")
        return
    spawner.configure_intersection(signals, null)
    var inbound: Dictionary = {}
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        var approach: String = Spawner.signal_approach_for_lane(lane, true)
        if approach != "" and not inbound.has(approach):
            inbound[approach] = lane
    if inbound.size() != 4:
        _fail("could not find four legal inbound approaches")
        return
    var active_order: Array[String] = ["N", "E", "S", "W"]
    for allowed in active_order:
        if signals.phase_name() != allowed + "_GREEN":
            _fail("green direction skipped " + allowed)
            return
        _verify_aspects(signals, allowed)
        if signals.has_conflicting_green():
            _fail("two sides were green")
            return
        for direction in active_order:
            var lane: CivicLaneData = inbound[direction]
            var car := CivicVehicleAgent.new()
            car.route = PackedInt32Array([lane.lane_id])
            car.active = true
            car.current_route_index = 0
            car.lane_distance_m = lane.length_m() - 7.0
            var held: bool = bool(spawner.apply_stop_line_observation(car, {"detected": false}).get("detected", false))
            if held != (direction != allowed):
                _fail("NPC %s ignored signal during %s green; held=%s" % [direction, allowed, str(held)])
                return
            car.free()
        signals.advance_fixed(12.0)
        if signals.phase_name() != allowed + "_AMBER":
            _fail("no amber warning for " + allowed)
            return
        _verify_aspects(signals, "")
        if signals.aspect_for_approach(allowed) != "amber":
            _fail("amber signal missing on " + allowed)
            return
        signals.advance_fixed(3.0)
        if signals.phase_name() != "ALL_RED_" + allowed:
            _fail("no all-red clearance for " + allowed)
            return
        _verify_aspects(signals, "")
        signals.advance_fixed(2.0)
    if signals.phase_name() != "N_GREEN":
        _fail("four-direction cycle failed to return to north")
        return

    var walkers := Walkers.new()
    walkers.pedestrian_count = 0
    root.add_child(walkers)
    walkers.configure_traffic(signals, spawner, null)
    # North is green; NS-conflicting crossing must be denied even when
    # South itself is red. EW crossing may start safely at cycle start.
    if walkers._can_cross(2) or not walkers._can_cross(0):
        _fail("NPC pedestrian tried to cross against a one-direction green")
        return
    signals.advance_fixed(6.0)
    if walkers._can_cross(0):
        _fail("pedestrian permitted to start too late before east green")
        return

    var saved: Dictionary = signals.snapshot()
    var restored := Signals.new(12.0, 3.0, 2.0)
    restored.enable_single_approach_mode()
    var json_value: Variant = JSON.parse_string(JSON.stringify(saved))
    if not restored.restore(json_value) or restored.phase_name() != signals.phase_name():
        _fail("single-green checkpoint JSON round-trip invalid")
        return
    var legacy := Signals.new(12.0, 3.0, 2.0)
    legacy.advance_fixed(17.0)
    var old_state: Dictionary = legacy.snapshot()
    old_state.erase("single_approach_mode")
    if not restored.restore(old_state) or restored.phase_name() != "E_GREEN":
        _fail("legacy paired-direction checkpoint was not safely migrated")
        return
    if not restored.single_approach_mode or restored.has_conflicting_green():
        _fail("legacy migration reopened two directions at once")
        return
    walkers.queue_free()
    spawner.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_09_SINGLE_APPROACH_RULES_PASS")
    quit(0)

func _verify_aspects(signals: CivicTrafficSignalController, green: String) -> void:
    for direction in ["N", "E", "S", "W"]:
        if green == direction and signals.aspect_for_approach(direction) != "green":
            _fail("correct approach not green: " + direction)
            return
        if green != direction and signals.aspect_for_approach(direction) == "green":
            _fail("perpendicular or opposite signal also green: " + direction)
            return

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
