extends SceneTree

const Builder = preload("res://scripts/world/junction_builder.gd")
const Agent = preload("res://scripts/traffic/vehicle_agent.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Manager = preload("res://scripts/traffic/intersection_reservations.gd")
const Behavior = preload("res://scripts/traffic/vehicle_behavior.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph := Builder.make_test_graph()
    var manager := Manager.new()
    var agent := Agent.new()
    root.add_child(agent)
    if not agent.configure(graph, PackedInt32Array([1, 4]), Profile.new()):
        _fail("vehicle setup failed")
        return
    var behavior := Behavior.new()
    assert(behavior.configure(agent, manager, 1))
    behavior.advance_fixed(1, 0.05, false)
    assert(behavior.state_name() == "approach")
    var length: float = graph.get_lane(1).length_m()
    agent.lane_distance_m = length - 2.0
    behavior.advance_fixed(2, 0.05, false)
    assert(behavior.state_name() == "waiting")
    assert(agent.stop_requested)
    manager.advance_to(3)
    behavior.advance_fixed(3, 0.05, true)
    assert(behavior.state_name() == "crossing")
    assert(manager.occupant("center") == 1)
    var other := Agent.new()
    root.add_child(other)
    assert(other.configure(graph, PackedInt32Array([3, 6]), Profile.new()))
    var competitor := Behavior.new()
    assert(competitor.configure(other, manager, 2))
    other.lane_distance_m = graph.get_lane(3).length_m() - 2.0
    competitor.advance_fixed(3, 0.05, true)
    assert(competitor.state_name() == "waiting")
    assert(other.stop_requested)
    agent.current_route_index = 1
    behavior.advance_fixed(4, 0.05, true)
    assert(manager.occupant("center") == -1)
    manager.advance_to(5)
    competitor.advance_fixed(5, 0.05, true)
    assert(competitor.state_name() == "crossing")
    competitor.interrupt("emergency")
    assert(competitor.state_name() == "recovery")
    assert(manager.occupant("center") == -1)
    var invalid := Behavior.new()
    assert(invalid.configure(other, manager, 3))
    other.route = PackedInt32Array()
    invalid.advance_fixed(6, 0.05, true)
    assert(invalid.state_name() == "recovery")
    print("CIVIC_CHAOS_VEHICLE_BEHAVIOR_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
