extends SceneTree
## Real expanded-city graph left-driving lane pair separation and legal joins.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Vehicle = preload("res://scripts/traffic/vehicle_agent.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_city_graph()
    if graph.lane_count() != 80 or not graph.validate().is_empty():
        _fail("city lane graph invalid after left-side separation: " + str(graph.validate()))
        return
    for first_id in range(100, 180, 2):
        var inbound: CivicLaneData = graph.get_lane(first_id)
        var reverse: CivicLaneData = graph.get_lane(first_id + 1)
        if inbound == null or reverse == null:
            _fail("opposing lane pair missing")
            return
        var in_points: PackedVector3Array = inbound.centerline
        var out_points: PackedVector3Array = reverse.centerline
        if in_points.size() != 4 or out_points.size() != 4:
            _fail("four-point left-side centerline missing")
            return
        if in_points[0].distance_to(out_points[3]) > 0.001 or in_points[3].distance_to(out_points[0]) > 0.001:
            _fail("lane pair endpoint connectivity lost")
            return
        var p: Vector3 = (in_points[1] + in_points[2]) * 0.5
        var q: Vector3 = (out_points[1] + out_points[2]) * 0.5
        if p.distance_to(q) < 2.45:
            _fail("opposing lanes share the same mid-road space")
            return
        var forward: Vector3 = (in_points[3] - in_points[0]).normalized()
        var left: Vector3 = Vector3(forward.z, 0.0, -forward.x)
        var center: Vector3 = (in_points[0] + in_points[3]) * 0.5
        if (p - center).dot(left) < 1.1:
            _fail("inbound traffic is not using the left side")
            return
        if (q - center).dot(left) > -1.1:
            _fail("reverse traffic not on its own left side")
            return
        for exit_lane_id in inbound.next_lane_ids:
            var exit_lane: CivicLaneData = graph.get_lane(exit_lane_id)
            if exit_lane == null:
                _fail("missing legal exit")
                return
            if exit_lane.centerline[exit_lane.centerline.size() - 1].distance_to(inbound.centerline[0]) < 0.001:
                _fail("immediate illegal U-turn allowed")
                return
            if exit_lane.centerline[0].distance_to(inbound.centerline[inbound.centerline.size() - 1]) > 0.001:
                _fail("connecting center junction was displaced")
                return
    var trial: Dictionary = Vehicle.sample_centerline(graph.get_lane(100).centerline, 12.0)
    if not trial.has("position") or not (trial["position"] is Vector3):
        _fail("vehicle sampling cannot follow new polyline")
        return
    print("CIVIC_CHAOS_TWO_WAY_LANE_SEPARATION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
