class_name CivicJunctionBuilder
extends RefCounted
## Creates a deterministic four-arm test junction and matching directed lane graph.

const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const CityRoadLayout = preload("res://scripts/world/city_road_layout.gd")

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

## Road centers come from the same grid used for the neighborhood mesh:
## center 0, secondary +/-46 and perimeter +/-120.
## Each adjacent pair of intersections has directed lanes in both directions.
## Road segments are routed through intersections; no U-turns are permitted.
static func make_city_graph() -> CivicRoadGraph:
    var graph := Graph.new()
    var coordinates: Array[float] = CityRoadLayout.coordinates()
    var lane_id := 100
    var arrivals: Dictionary = {}
    var departures: Dictionary = {}
    for x_index in range(coordinates.size()):
        for z_index in range(coordinates.size()):
            var here := Vector3(coordinates[x_index], 0.0, coordinates[z_index])
            var key := "%d:%d" % [x_index, z_index]
            if not arrivals.has(key):
                arrivals[key] = []
                departures[key] = []
            for neighbor in [Vector2i(x_index + 1, z_index), Vector2i(x_index, z_index + 1)]:
                if neighbor.x >= coordinates.size() or neighbor.y >= coordinates.size():
                    continue
                var there := Vector3(coordinates[neighbor.x], 0.0, coordinates[neighbor.y])
                var target_key := "%d:%d" % [neighbor.x, neighbor.y]
                if not arrivals.has(target_key):
                    arrivals[target_key] = []
                    departures[target_key] = []
                for direction in range(2):
                    var lane := Lane.new()
                    lane.lane_id = lane_id
                    lane_id += 1
                    var origin: Vector3 = here if direction == 0 else there
                    var destination: Vector3 = there if direction == 0 else here
                    lane.centerline = _city_left_side_centerline(origin, destination)
                    lane.speed_limit_mps = 8.0
                    graph.add_lane(lane)
                    var source_key: String = key if direction == 0 else target_key
                    var destination_key: String = target_key if direction == 0 else key
                    departures[source_key].append(lane.lane_id)
                    arrivals[destination_key].append(lane.lane_id)
    for intersection_key in arrivals.keys():
        for incoming_id in arrivals[intersection_key]:
            var incoming: CivicLaneData = graph.get_lane(incoming_id)
            var options := PackedInt32Array()
            for outgoing_id in departures[intersection_key]:
                var outgoing: CivicLaneData = graph.get_lane(outgoing_id)
                # Do not immediately reverse onto the same street segment.
                if outgoing.centerline[outgoing.centerline.size() - 1].distance_to(incoming.centerline[0]) > 0.01:
                    options.append(outgoing_id)
            incoming.next_lane_ids = options
    return graph

## Indian left-side traffic: keep two-way vehicles on distinct mid-road paths.
## Enter/exit the central junction node so legal route connections remain exact.
## This is a lane-separation baseline; junction conflict scheduling still needs
## dedicated intersection handling and physical playtests.
static func _city_left_side_centerline(start: Vector3, finish: Vector3) -> PackedVector3Array:
    var direction: Vector3 = finish - start
    var road_length: float = direction.length()
    if road_length < 10.0:
        return PackedVector3Array([start, finish])
    var forward: Vector3 = direction / road_length
    var left: Vector3 = Vector3(forward.z, 0.0, -forward.x)
    var shoulder: float = 1.25
    var ramp_length: float = 4.0
    return PackedVector3Array([
        start,
        start + forward * ramp_length + left * shoulder,
        finish - forward * ramp_length + left * shoulder,
        finish
    ])
