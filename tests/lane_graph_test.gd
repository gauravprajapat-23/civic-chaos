extends SceneTree
## Godot --headless --path . --script res://tests/lane_graph_test.gd

const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")

func _initialize() -> void:
    call_deferred("_run")

func _lane(id: int, points: PackedVector3Array) -> CivicLaneData:
    var lane := Lane.new()
    lane.lane_id = id
    lane.centerline = points
    return lane

func _run() -> void:
    var graph := Graph.new()
    var first := _lane(1, PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0)]))
    first.next_lane_ids = PackedInt32Array([2])
    var second := _lane(2, PackedVector3Array([Vector3(10, 0, 0), Vector3(20, 0, 0)]))
    if not graph.add_lane(first) or not graph.add_lane(second):
        _fail("valid lanes rejected")
        return
    if graph.add_lane(first) or graph.add_lane(_lane(-1, PackedVector3Array())):
        _fail("duplicate or invalid ID accepted")
        return
    if not graph.validate().is_empty() or graph.lane_count() != 2:
        _fail("valid graph failed validation")
        return
    if graph.outgoing_legal_lanes(1, 1) != [2]:
        _fail("legal outgoing lane missing")
        return
    second.allowed_vehicle_mask = 2
    if not graph.outgoing_legal_lanes(1, 1).is_empty():
        _fail("vehicle restrictions ignored")
        return
    second.allowed_vehicle_mask = 15
    first.next_lane_ids = PackedInt32Array([99])
    if graph.validate().is_empty():
        _fail("broken connection accepted")
        return
    first.next_lane_ids = PackedInt32Array([2])
    second.centerline = PackedVector3Array([Vector3(10, 0, 0), Vector3(10, 0, 0)])
    if second.geometry_errors().is_empty():
        _fail("zero-length lane accepted")
        return
    second.centerline = PackedVector3Array([Vector3(100, 0, 0), Vector3(110, 0, 0)])
    if graph.validate().is_empty():
        _fail("disconnected geometry accepted")
        return
    second.centerline = PackedVector3Array([Vector3(10, 0, 0), Vector3(20, 0, 0)])
    second.is_wrong_way_connector = true
    if graph.validate().is_empty() or not graph.outgoing_legal_lanes(1, 1).is_empty():
        _fail("wrong-way connector exposed to legal routing")
        return
    print("CIVIC_CHAOS_LANE_GRAPH_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
