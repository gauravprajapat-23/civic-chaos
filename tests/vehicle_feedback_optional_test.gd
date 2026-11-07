extends SceneTree
## AUD-001: optional presentation must not be a hard dependency of traffic.
## A vehicle remains route-capable with feedback enabled, disabled or missing.
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const VEHICLE_SCENE: String = "res://scenes/traffic/vehicle_agent.tscn"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene_resource: Resource = load(VEHICLE_SCENE)
    if not (scene_resource is PackedScene):
        _fail("cannot load physical vehicle scene for optional-feedback regression")
        return
    var stage := Node3D.new()
    root.add_child(stage)
    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 33
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -40)])
    if not graph.add_lane(lane):
        _fail("test lane could not be registered")
        return

    for mode in ["disabled", "missing", "normal"]:
        var node: Node = (scene_resource as PackedScene).instantiate()
        if not (node is CivicVehicleAgent):
            if is_instance_valid(node):
                node.free()
            _fail("vehicle scene root did not construct for mode %s" % mode)
            return
        var vehicle: CivicVehicleAgent = node as CivicVehicleAgent
        if mode == "disabled":
            vehicle.feedback_enabled = false
        elif mode == "missing":
            vehicle.feedback_script_path = "res://scripts/npc/__missing_optional_feedback__.gd"
        vehicle.physics_obstacle_checks_enabled = false
        stage.add_child(vehicle)
        if mode == "normal":
            if not is_instance_valid(vehicle.feedback) or not vehicle.feedback.has_method("observe_vehicle"):
                _fail("default car lost its optional presentation cues")
                return
        elif is_instance_valid(vehicle.feedback):
            _fail("car created visual feedback despite disabled/missing cue code")
            return
        if not vehicle.configure(graph, PackedInt32Array([33]), Profile.new()):
            _fail("car failed to configure when feedback mode was %s" % mode)
            return
        var initial: Vector3 = vehicle.global_position
        for tick in range(16):
            vehicle.advance_fixed(0.05)
        if vehicle.global_position.distance_to(initial) <= 0.1 or not vehicle.active:
            _fail("optional feedback mode %s blocked ordinary car motion" % mode)
            return
        if mode == "normal" and str(vehicle.feedback.get("state")) != "moving":
            _fail("normal optional feedback no longer receives vehicle movement")
            return
        vehicle.queue_free()
        await physics_frame
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_FEEDBACK_OPTIONAL_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
