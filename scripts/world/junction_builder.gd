class_name CivicJunctionBuilder
extends RefCounted
## Creates a deterministic four-arm test junction and matching directed lane graph.

const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const CityRoadLayout = preload("res://scripts/world/city_road_layout.gd")
const CityNetwork = preload("res://scripts/world/city_network_definition.gd")
const Organic = preload("res://scripts/world/organic_road_geometry.gd")
const EastCurves = preload("res://scripts/world/world_002_road_curves.gd")
const NeighborhoodLink = preload("res://scripts/world/world_002_neighborhood_connector.gd")

static func make_test_graph() -> CivicRoadGraph:
    var graph := Graph.new()
    # Four incoming lanes converge on the junction; each has an outbound continuation.
    # Match Indian left-side road placement on the isolated fixture too:
    # overlapping opposing lane centerlines caused permanent head-on queues.
    var endpoints: Array[Vector3] = [
        Vector3(0, 0, -20), Vector3(0, 0, 0),
        Vector3(20, 0, 0), Vector3(0, 0, 0),
        Vector3(0, 0, 20), Vector3(0, 0, 0),
        Vector3(-20, 0, 0), Vector3(0, 0, 0)
    ]
    for arm in range(4):
        var inbound := Lane.new()
        inbound.lane_id = arm * 2 + 1
        inbound.centerline = _city_left_side_centerline(endpoints[arm * 2], Vector3.ZERO, 1.6)
        var outbound := Lane.new()
        outbound.lane_id = arm * 2 + 2
        outbound.centerline = _city_left_side_centerline(Vector3.ZERO, endpoints[arm * 2], 1.6)
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
    var arrivals: Dictionary = {}
    var departures: Dictionary = {}
    # Use the canonical WORLD-001A fixture, preserving old edge traversal
    # and lane IDs exactly. Later WORLD-001B can introduce non-grid segments
    # by updating the network, not creating a competing traffic graph.
    for node in CityNetwork.nodes():
        var key: String = str(node["id"])
        arrivals[key] = []
        departures[key] = []
    for road in CityNetwork.roads():
        var here: Vector3 = road["start"]
        var there: Vector3 = road["end"]
        for direction in range(2):
            var lane := Lane.new()
            lane.lane_id = int(road["lane_forward"]) if direction == 0 else int(road["lane_reverse"])
            var origin: Vector3 = here if direction == 0 else there
            var destination: Vector3 = there if direction == 0 else here
            if bool(road.get("organic_pilot", false)):
                lane.centerline = Organic.driving_lane(origin, destination)
            elif bool(road.get("world_002_curve", false)):
                lane.centerline = EastCurves.driving_lane(origin, destination)
            elif bool(road.get("world_002_connector", false)):
                lane.centerline = NeighborhoodLink.driving_lane(origin, destination)
            elif bool(road["challenge"]):
                lane.centerline = _city_chicane_centerline(origin, destination)
            else:
                lane.centerline = _city_left_side_centerline(origin, destination)
            lane.speed_limit_mps = float(road["speed_limit_mps"])
            graph.add_lane(lane)
            var source_key: String = str(road["from_node"]) if direction == 0 else str(road["to_node"])
            var destination_key: String = str(road["to_node"]) if direction == 0 else str(road["from_node"])
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
static func _city_left_side_centerline(start: Vector3, finish: Vector3, shoulder: float = 1.25) -> PackedVector3Array:
    var direction: Vector3 = finish - start
    var road_length: float = direction.length()
    if road_length < 10.0:
        return PackedVector3Array([start, finish])
    var forward: Vector3 = direction / road_length
    var left: Vector3 = Vector3(forward.z, 0.0, -forward.x)
    var ramp_length: float = 4.0
    return PackedVector3Array([
        start,
        start + forward * ramp_length + left * shoulder,
        finish - forward * ramp_length + left * shoulder,
        finish
    ])

## MAP-CHALLENGE-01: a real but bounded change of heading on outer
## streets. 4m junction ramps and endpoints remain EXACTLY unchanged,
## preserving central/outer priority logic and graph connectivity.
## Both directions bend to their own LEFT; the opposing lane remains
## separated by >= 2.5m throughout (no head-on centerline overlap).
static func _city_chicane_centerline(start: Vector3, finish: Vector3) -> PackedVector3Array:
    var direction: Vector3 = finish - start
    var length: float = direction.length()
    if length < 50.0:
        return _city_left_side_centerline(start, finish)
    var forward: Vector3 = direction / length
    var left: Vector3 = Vector3(forward.z, 0.0, -forward.x)
    var shoulder: float = 1.25
    var bump: float = 0.75
    return PackedVector3Array([
        start,
        start + forward * 4.0 + left * shoulder,
        start + forward * length * 0.30 + left * shoulder,
        start + forward * length * 0.45 + left * (shoulder + bump),
        start + forward * length * 0.55 + left * (shoulder + bump),
        start + forward * length * 0.70 + left * shoulder,
        finish - forward * 4.0 + left * shoulder,
        finish
    ])
