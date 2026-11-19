extends SceneTree
## MAP-CHALLENGE-01 — interesting routes must remain safe, connected
## and physically paved. No hidden colliders or invented lane shortcuts.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Layout = preload("res://scripts/world/city_road_layout.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Neighborhood = preload("res://scenes/world/neighborhood.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    if not graph.validate().is_empty():
        _fail("new winding city road graph failed validation")
        return
    var challenged: int = 0
    var matching: Dictionary = {}
    for section in Layout.challenge_segments():
        matching[str(section["start"]) + "|" + str(section["end"])] = true
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        var start: Vector3 = lane.centerline[0]
        var finish: Vector3 = lane.centerline[-1]
        var challenging: bool = Layout.is_challenge_segment(start, finish)
        if challenging:
            challenged += 1
            if lane.centerline.size() < 7 or lane.speed_limit_mps > 6.0:
                _fail("challenge road lacks a real slow multi-turn centerline")
                return
            var expected_length: float = start.distance_to(finish)
            if absf(expected_length - 74.0) > 0.01:
                _fail("challenge unexpectedly crosses a mission road")
                return
            var direction: Vector3 = (finish - start).normalized()
            var left: Vector3 = Vector3(direction.z, 0, -direction.x)
            var max_lateral: float = 0.0
            for point in lane.centerline:
                var longitudinal: float = (point - start).dot(direction)
                var lateral: float = (point - start).dot(left)
                if longitudinal < -0.01 or longitudinal > expected_length + 0.01 or (
                        lateral < -0.01 or lateral > 2.1):
                    _fail("S-bend left the safe 8m carriageway")
                    return
                max_lateral = maxf(max_lateral, lateral)
            if max_lateral < 1.9:
                _fail("challenge road is still nearly straight")
                return
        else:
            if lane.centerline.size() != 4:
                _fail("normal civic junction or incident path changed")
                return
        for next_id in graph.outgoing_legal_lanes(id, 1):
            var successor: CivicLaneData = graph.get_lane(next_id)
            if successor == null or successor.centerline[0].distance_to(finish) > 0.05:
                _fail("road turn became a disconnected shortcut")
                return
    if challenged != 16:
        _fail("expected eight reversible S-bends, found %d lanes" % challenged)
        return
    var world := Neighborhood.instantiate() as CivicNeighborhood
    root.add_child(world)
    await process_frame
    var visual_signs: int = 0
    for index in range(8):
        var sign: Node3D = world.get_node_or_null("ChicaneWarning_%d" % index)
        if sign == null or sign.get_node_or_null("S_Bend_Sign") == null:
            _fail("winding road has no visible roadside warning")
            return
        for child in sign.get_children():
            if child is CollisionObject3D or child is CollisionShape3D:
                _fail("visual road challenge secretly added a solid obstacle")
                return
        visual_signs += 1
    if visual_signs != 8:
        _fail("not all challenge streets are marked")
        return
    var traffic := Spawner.new() as CivicTrafficSpawner
    root.add_child(traffic)
    if not traffic.configure(graph, 777, true):
        _fail("new drivable map rejected by traffic spawner")
        return
    var right_angle_turns: int = 0
    for inbound_id in graph.sorted_lane_ids():
        var inbound: CivicLaneData = graph.get_lane(inbound_id)
        var options: Array[int] = traffic._open_route_options(
            graph.outgoing_legal_lanes(inbound_id, 1))
        if options.size() < 2:
            continue
        for i in range(5):
            var chosen_id: int = traffic._choose_city_turn(inbound_id, options)
            if not options.has(chosen_id):
                _fail("unexpected turn picked a nonexistent/closed road")
                return
            var next: CivicLaneData = graph.get_lane(chosen_id)
            var a: Vector3 = (inbound.centerline[-1] - inbound.centerline[0]).normalized()
            var b: Vector3 = (next.centerline[-1] - next.centerline[0]).normalized()
            if absf(a.dot(b)) < 0.35:
                right_angle_turns += 1
    if right_angle_turns < 15:
        _fail("route planner still avoids all unexpected turns")
        return
    traffic.queue_free()
    world.queue_free()
    print("CIVIC_CHAOS_MAP_CHALLENGE_01_BENDS_AND_TURNS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
