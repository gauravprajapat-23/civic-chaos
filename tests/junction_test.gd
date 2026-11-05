extends SceneTree
const Builder = preload("res://scripts/world/junction_builder.gd")
const Junction = preload("res://scenes/world/four_way_junction.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph := Builder.make_test_graph()
    if graph.lane_count() != 8 or not graph.validate().is_empty():
        _fail("junction graph invalid")
        return
    for id in graph.sorted_lane_ids():
        var lane := graph.get_lane(id)
        if absf(lane.length_m() - 20.0) > 0.01:
            _fail("lane length mismatch")
            return
        if id % 2 == 1 and graph.outgoing_legal_lanes(id, 1).size() != 3:
            _fail("turn restrictions mismatch")
            return
    var junction := Junction.instantiate()
    root.add_child(junction)
    await process_frame
    var count := 0
    for child in junction.get_children():
        if child is CivicRoadSegment:
            count += 1
            if child.start_point != Vector3.ZERO or absf(child.end_point.length() - 20.0) > 0.01:
                _fail("visual segment geometry mismatch")
                return
    if count != 4:
        _fail("expected four road arms")
        return
    junction.queue_free()
    print("CIVIC_CHAOS_JUNCTION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
