extends SceneTree

const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Vehicle = preload("res://scripts/traffic/vehicle_agent.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Sensor = preload("res://scripts/traffic/traffic_sensor.gd")
const Following = preload("res://scripts/traffic/following_controller.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 1
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(100, 0, 0)])
    graph.add_lane(lane)
    var profile := Profile.new()
    var lead := Vehicle.new()
    var follower := Vehicle.new()
    root.add_child(lead)
    root.add_child(follower)
    if not lead.configure(graph, PackedInt32Array([1]), profile) or not follower.configure(graph, PackedInt32Array([1]), profile):
        _fail("setup rejected")
        return
    lead.lane_distance_m = 15.0
    var vehicles: Array[CivicVehicleAgent] = [lead, follower]
    var observation: Dictionary = Sensor.nearest_lead(follower, vehicles)
    if not observation["detected"] or absf(float(observation["gap_m"]) - 15.0) > 0.001:
        _fail("lead detection incorrect")
        return
    for tick in range(200):
        observation = Sensor.nearest_lead(follower, vehicles)
        follower.set_lead_observation(float(observation["gap_m"]), float(observation["lead_speed_mps"]))
        follower.advance_fixed(0.05)
        if lead.lane_distance_m - follower.lane_distance_m < follower.minimum_gap_m - 0.001:
            _fail("stationary lead gap violated")
            return
    if follower.speed_mps > 0.1:
        _fail("follower failed to stop")
        return
    follower.configure(graph, PackedInt32Array([1]), profile)
    lead.lane_distance_m = 20.0
    lead.speed_mps = 2.0
    for tick in range(200):
        lead.advance_fixed(0.05)
        observation = Sensor.nearest_lead(follower, vehicles)
        follower.set_lead_observation(float(observation["gap_m"]), float(observation["lead_speed_mps"]))
        follower.advance_fixed(0.05)
        if lead.lane_distance_m - follower.lane_distance_m < follower.minimum_gap_m - 0.001:
            _fail("moving lead gap violated")
            return
    follower.configure(graph, PackedInt32Array([1]), profile)
    var obstacle: Array[Dictionary] = [{"lane_id": 1, "distance_m": 8.0}]
    for tick in range(200):
        observation = Sensor.nearest_lead(follower, [follower], obstacle)
        follower.set_lead_observation(float(observation["gap_m"]), 0.0)
        follower.advance_fixed(0.05)
        if follower.lane_distance_m > 8.0 - follower.minimum_gap_m + 0.001:
            _fail("static obstacle gap violated")
            return
    if Following.safe_speed(2.0, 0.0, 6.0, 2.0, 0.8) > 0.001:
        _fail("zero-clearance speed unsafe")
        return
    print("CIVIC_CHAOS_FOLLOWING_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
