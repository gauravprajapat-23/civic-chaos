extends SceneTree
## TRAFFIC-FIX-13: a vehicle state cue must reflect distance actually
## travelled, not stale proposed velocity or an old mission status.
const Feedback = preload("res://scripts/npc/agent_feedback.gd")
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var feedback := Feedback.new() as CivicAgentFeedback
    root.add_child(feedback)
    feedback.observe_displacement(0.0, 0.05, true, false)
    if feedback.state != "stopped" or feedback.cue_label.text != "Stopped":
        _fail("zero actual movement shown as Moving")
        return
    feedback.observe_displacement(0.6, 0.05, true, false)
    if feedback.state != "moving" or feedback.cue_label.text != "Moving":
        _fail("accepted car travel not shown as Moving")
        return
    feedback.observe_displacement(0.0, 0.05, true, false)
    if feedback.state != "stopped" or feedback.cue_label.text != "Stopped":
        _fail("stale moving label survived an actual stop")
        return
    feedback.observe_displacement(0.0, 0.05, false, false)
    if feedback.state != "completed" or feedback.cue_label.text != "":
        _fail("finished car left floating status text")
        return

    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 1
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -25)])
    if not graph.add_lane(lane):
        _fail("test lane invalid")
        return
    var car := CarScene.instantiate() as CivicVehicleAgent
    root.add_child(car)
    if not car.configure(graph, PackedInt32Array([1]), Profile.new()):
        _fail("test car configuration failed")
        return
    car.physics_obstacle_checks_enabled = false
    for frame in range(60):
        car.advance_fixed(0.05)
    var actual: CivicAgentFeedback = car.get_node("AgentFeedback") as CivicAgentFeedback
    if actual == null or actual.state != "moving":
        _fail("real car did not update its feedback from accepted movement")
        return
    car.stop_requested = true
    for frame in range(60):
        car.advance_fixed(0.05)
    if actual.state != "stopped":
        _fail("actual car remained labeled Moving while stopped")
        return
    car.queue_free()
    feedback.queue_free()
    print("CIVIC_CHAOS_TRAFFIC_FIX_13_ACTUAL_LABEL_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
