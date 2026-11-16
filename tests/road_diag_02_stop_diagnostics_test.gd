extends SceneTree
## ROAD-DIAG-02: classification is read-only and must report the actual
## stop-line authority plus the same physical blocker that stopped motion.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const Signals = preload("res://scripts/traffic/traffic_signal_controller.gd")
const StopDiag = preload("res://scripts/traffic/traffic_stop_diagnostics.gd")
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if StopDiag.signal_reason("red", false) != "red_signal" or StopDiag.signal_reason("green", true) != "crossing_occupied" or StopDiag.signal_reason("green", false) != "":
        _fail("central signal classification changed")
        return
    if StopDiag.outer_reason("zone_occupied") != "outer_zone_occupied" or StopDiag.outer_reason("higher_priority_lane") != "outer_priority":
        _fail("outer priority classification changed")
        return
    if StopDiag.should_log(119) or not StopDiag.should_log(120) or StopDiag.should_log(121) or not StopDiag.should_log(240):
        _fail("jam logs are not throttled")
        return

    var graph: CivicRoadGraph = Builder.make_city_graph()
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    if not spawner.configure(graph, 312, true):
        _fail("city spawner could not configure")
        return
    var signals := Signals.new(4.0, 2.0, 1.0)
    spawner.configure_intersection(signals, null)
    var east_lane: CivicLaneData
    for id in graph.sorted_lane_ids():
        var lane: CivicLaneData = graph.get_lane(id)
        if Spawner.signal_approach_for_lane(lane, true) == "E":
            east_lane = lane
            break
    if east_lane == null:
        _fail("no eastbound red approach fixture")
        return
    var candidate := CivicVehicleAgent.new()
    candidate.route = PackedInt32Array([east_lane.lane_id])
    candidate.lane_distance_m = east_lane.length_m() - 7.0
    var before: Dictionary = spawner.apply_stop_line_observation(candidate, {"detected": false})
    if not bool(before.get("detected", false)) or str(spawner._observation_hold_reason.get(candidate.get_instance_id(), "")) != "red_signal":
        _fail("red signal was not labeled from its own stopping decision")
        return
    signals.advance_fixed(7.0)
    var after: Dictionary = spawner.apply_stop_line_observation(candidate, {"detected": false})
    if bool(after.get("detected", false)) or str(spawner._observation_hold_reason.get(candidate.get_instance_id(), "")) != "":
        _fail("green signal kept stale red label")
        return
    candidate.free()
    spawner.queue_free()

    var stage := Node3D.new()
    root.add_child(stage)
    var road := _box("RoadFloor", Vector3(15, -0.25, 0), Vector3(40, 0.5, 10))
    stage.add_child(road)
    var building := _box("SolidWorldObstacle", Vector3(9, 1.0, 0), Vector3(2, 2, 3))
    stage.add_child(building)
    var simple_graph := CivicRoadGraph.new()
    var lane := CivicLaneData.new()
    lane.lane_id = 1
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(30, 0, 0)])
    simple_graph.add_lane(lane)
    var car := VehicleScene.instantiate() as CivicVehicleAgent
    car.feedback_enabled = false
    stage.add_child(car)
    if not car.configure(simple_graph, PackedInt32Array([1]), Profile.new()):
        _fail("physical vehicle fixture could not configure")
        return
    await physics_frame
    var saw_block: bool = false
    for tick in range(120):
        car.advance_fixed(0.05)
        await physics_frame
        if car.last_physics_hold_reason == "world_collider":
            saw_block = true
            if not car.last_physics_blocker.contains("SolidWorldObstacle"):
                _fail("blocked vehicle did not name its real world collider")
                return
            if StopDiag.stop_reason(car, "") != "world_collider":
                _fail("actual physical hold lost to fallback classification")
                return
            break
    if not saw_block:
        _fail("solid world obstruction did not produce collision evidence")
        return
    building.global_position = Vector3(9.0, 1.0, 9.0)
    await physics_frame
    var cleared: bool = false
    for tick in range(120):
        car.advance_fixed(0.05)
        await physics_frame
        if car.speed_mps > 0.5 and car.last_physics_hold_reason == "":
            cleared = true
            break
    if not cleared:
        _fail("clear road did not clear stop diagnostics and resume movement")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_ROAD_DIAG_02_STOP_DIAGNOSTICS_PASS")
    quit(0)

func _box(label: String, at: Vector3, size: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = label
    body.position = at
    body.collision_layer = 1
    body.collision_mask = 0
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    return body

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
