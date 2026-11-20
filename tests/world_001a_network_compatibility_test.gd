extends SceneTree
## WORLD-001A: verify the new source-of-truth reproduces legacy city
## exactly. Do not accept merely a graph that still validates: lane IDs,
## positions, challenge speeds, and legal turn order must remain unchanged.
const Network = preload("res://scripts/world/city_network_definition.gd")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Layout = preload("res://scripts/world/city_road_layout.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var nodes: Array[Dictionary] = Network.nodes()
    var roads: Array[Dictionary] = Network.roads()
    _require(Network.SCHEMA_VERSION == 1, "network schema must be versioned")
    _require(Network.FUTURE_LANE_BASE > 179, "future lane IDs collide with legacy")
    _require(nodes.size() == 25, "legacy 5x5 nodes changed")
    _require(roads.size() == 40, "legacy 40 bidirectional road segments changed")
    _require(Network.bounds() == Rect2(-120, -120, 240, 240), "map bounds changed")
    _require(Network.validate(nodes, roads).is_empty(), "network structure invalid")
    _require(Network.nodes() == nodes and Network.roads() == roads,
        "road generation is nondeterministic")
    var first: Dictionary = roads[0]
    _require(first["from_node"] == "0:0" and first["to_node"] == "1:0",
        "legacy traversal changed at first edge")
    _require(int(first["lane_forward"]) == 100 and int(first["lane_reverse"]) == 101,
        "first lane IDs changed")
    var last: Dictionary = roads[roads.size() - 1]
    _require(int(last["lane_reverse"]) == 179, "last lane ID changed")
    var center: Dictionary = nodes[12]
    _require(center["id"] == "2:2" and center["position"] == Vector3.ZERO and (
        center["junction_type"] == Network.SIGNALIZED), "central signal anchor changed")
    var graph: CivicRoadGraph = Builder.make_city_graph()
    _require(graph.lane_count() == 80, "existing traffic lane count changed")
    _require(graph.validate().is_empty(), "existing traffic graph no longer validates")
    var axes: Array[float] = Layout.coordinates()
    var index: int = 0
    var seen: Dictionary = {}
    for xi in range(axes.size()):
        for zi in range(axes.size()):
            var here := Vector3(axes[xi], 0.0, axes[zi])
            for neighbor in [Vector2i(xi + 1, zi), Vector2i(xi, zi + 1)]:
                if neighbor.x >= axes.size() or neighbor.y >= axes.size():
                    continue
                var there := Vector3(axes[neighbor.x], 0.0, axes[neighbor.y])
                var edge: Dictionary = roads[index]
                _require(edge["start"] == here and edge["end"] == there,
                    "road coordinates differ from original city layout")
                for direction in range(2):
                    var id: int = 100 + index * 2 + direction
                    var lane: CivicLaneData = graph.get_lane(id)
                    _require(lane != null and not seen.has(id),
                        "legacy lane ID missing or duplicated")
                    seen[id] = true
                    if lane == null:
                        continue
                    var source: Vector3 = here if direction == 0 else there
                    var target: Vector3 = there if direction == 0 else here
                    _require(lane.centerline[0] == source and (
                        lane.centerline[lane.centerline.size() - 1] == target),
                        "legacy lane endpoints moved")
                    var expected_speed: float = 5.5 if Layout.is_challenge_segment(
                        source, target) else 8.0
                    _require(is_equal_approx(lane.speed_limit_mps, expected_speed),
                        "challenge road speed changed")
                    _require(lane.next_lane_ids.size() <= 3,
                        "immediate U-turn or illegal junction turn introduced")
                index += 1
    _require(seen.size() == 80, "missing lane identity")
    # An invalid modified network must be rejected by the validator.
    var duplicate: Array[Dictionary] = []
    for road in roads:
        duplicate.append(road.duplicate(true))
    duplicate[1]["lane_forward"] = int(roads[0]["lane_forward"])
    _require(not Network.validate(nodes, duplicate).is_empty(),
        "duplicate lane IDs accepted")
    if failures == 0:
        print("CIVIC_CHAOS_WORLD_001A_NETWORK_PASS")
    else:
        print("CIVIC_CHAOS_WORLD_001A_NETWORK_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)

func _require(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD-001A: " + reason)
