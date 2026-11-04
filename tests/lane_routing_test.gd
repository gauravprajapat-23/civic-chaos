extends SceneTree
## A* regression: weighted path, deterministic ties, blocked lanes, restrictions, unreachable.

const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Router = preload("res://scripts/traffic/lane_router.gd")

func _initialize() -> void:
    call_deferred("_run")

func _lane(id: int, a: Vector3, b: Vector3, speed: float = 10.0) -> CivicLaneData:
    var lane := Lane.new()
    lane.lane_id = id
    lane.centerline = PackedVector3Array([a, b])
    lane.speed_limit_mps = speed
    return lane

func _run() -> void:
    var graph := Graph.new()
    var a := _lane(1, Vector3(0, 0, 0), Vector3(10, 0, 0))
    var b := _lane(2, Vector3(10, 0, 0), Vector3(20, 0, 0), 2.0)
    var c := _lane(3, Vector3(10, 0, 0), Vector3(20, 0, 0), 10.0)
    var d := _lane(4, Vector3(20, 0, 0), Vector3(30, 0, 0))
    a.next_lane_ids = PackedInt32Array([2, 3])
    b.next_lane_ids = PackedInt32Array([4])
    c.next_lane_ids = PackedInt32Array([4])
    for lane in [a, b, c, d]:
        if not graph.add_lane(lane):
            _fail("could not construct graph")
            return
    var router := Router.new(graph)
    var shortest: Dictionary = router.find_route(1, 4, 1)
    if not shortest["ok"] or shortest["path"] != PackedInt32Array([1, 3, 4]):
        _fail("weighted shortest path incorrect")
        return
    var detour: Dictionary = router.find_route(1, 4, 1, PackedInt32Array([3]))
    if not detour["ok"] or detour["path"] != PackedInt32Array([1, 2, 4]):
        _fail("blocked lane detour incorrect")
        return
    b.allowed_vehicle_mask = 2
    if router.find_route(1, 4, 1, PackedInt32Array([3]))["reason"] != "unreachable":
        _fail("vehicle restriction ignored")
        return
    if router.find_route(1, 4, 1, PackedInt32Array([4]))["reason"] != "restricted_endpoint":
        _fail("blocked goal accepted")
        return
    if router.find_route(1, 999, 1)["reason"] != "unknown_lane":
        _fail("unknown destination accepted")
        return
    if router.find_route(1, 4, 1, PackedInt32Array(), {3: -1.0})["reason"] != "invalid_extra_cost":
        _fail("negative penalty accepted")
        return
    b.allowed_vehicle_mask = 15
    b.speed_limit_mps = 10.0
    var tie: Dictionary = router.find_route(1, 4, 1)
    if tie["path"] != PackedInt32Array([1, 2, 4]):
        _fail("equal-cost tie not deterministic")
        return
    print("CIVIC_CHAOS_ROUTING_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
