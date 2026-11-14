extends SceneTree
## AUD3: downstream red-light stops must not masquerade as incident gridlock.
const Live = preload("res://scripts/civic/wrong_way_live_mission.gd")
const Vehicle = preload("res://scripts/traffic/vehicle_agent.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var live: CivicWrongWayLiveMission = Live.new() as CivicWrongWayLiveMission
    var upstream: CivicVehicleAgent = Vehicle.new() as CivicVehicleAgent
    var downstream: CivicVehicleAgent = Vehicle.new() as CivicVehicleAgent
    live.followers.append(upstream)
    live.followers.append(downstream)
    upstream.active = true
    downstream.active = true
    upstream.current_route_index = 0
    upstream.lane_distance_m = Live.OFFENDER_DISTANCE - 2.0
    upstream.speed_mps = 0.0
    downstream.current_route_index = 0
    downstream.lane_distance_m = Live.OFFENDER_DISTANCE + 10.0
    downstream.speed_mps = 0.0
    live.moved_ids[upstream.get_instance_id()] = true
    live.moved_ids[downstream.get_instance_id()] = true
    if live._actual_stopped_count() != 1:
        _fail("normal red-light stop counted as blocked wrong-way queue")
        return
    upstream.lane_distance_m = Live.OFFENDER_DISTANCE + 7.0
    if live._actual_stopped_count() != 0:
        _fail("incident queue did not clear after both cars passed obstruction")
        return
    if not Live._passed_incident(downstream) or not Live._passed_incident(upstream):
        _fail("cars physically beyond obstruction not considered passed")
        return
    upstream.lane_distance_m = Live.OFFENDER_DISTANCE
    if Live._passed_incident(upstream):
        _fail("car still at obstruction incorrectly counted as released")
        return
    upstream.current_route_index = 1
    if not Live._passed_incident(upstream):
        _fail("car entering legal exit not recognized")
        return
    live.free()
    print("CIVIC_CHAOS_AUD3_WRONG_WAY_SIGNAL_RECOVERY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
