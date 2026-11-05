class_name CivicJunctionBuilder
extends RefCounted
## Creates a deterministic four-arm test junction and matching directed lane graph.

const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")

static func make_test_graph() -> CivicRoadGraph:
    var graph := Graph.new()
    # Four incoming lanes converge on the junction; each has an outbound continuation.
    var endpoints: Array[Vector3] = [
        Vector3(0, 0, -20), Vector3(0, 0, 0),
        Vector3(20, 0, 0), Vector3(0, 0, 0),
        Vector3(0, 0, 20), Vector3(0, 0, 0),
        Vector3(-20, 0, 0), Vector3(0, 0, 0)
    ]
    for arm in range(4):
        var inbound := Lane.new()
        inbound.lane_id = arm * 2 + 1
        inbound.centerline = PackedVector3Array([endpoints[arm * 2], Vector3.ZERO])
        var outbound := Lane.new()
        outbound.lane_id = arm * 2 + 2
        outbound.centerline = PackedVector3Array([Vector3.ZERO, endpoints[arm * 2]])
        inbound.next_lane_ids = PackedInt32Array([2, 4, 6, 8])
        # Do not U-turn onto the same arm.
        var exits := PackedInt32Array()
        for target in [2, 4, 6, 8]:
            if target != outbound.lane_id:
                exits.append(target)
        inbound.next_lane_ids = exits
        graph.add_lane(inbound)
        graph.add_lane(outbound)
    return graph

static func make_road_visuals(parent: Node3D) -> void:
    var scene := load("res://scenes/world/road_segment.tscn") as PackedScene
    for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
        var road := scene.instantiate() as CivicRoadSegment
        road.start_point = Vector3.ZERO
        road.end_point = direction * 20.0
        parent.add_child(road)
