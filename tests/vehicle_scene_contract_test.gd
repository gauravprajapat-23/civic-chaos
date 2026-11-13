extends SceneTree
## AUD-001: reproduce the vehicle scene construction fault independently
## of spawner traffic demand, so missing scripts/collision shapes are visible.
const VehicleScenePath: String = "res://scenes/traffic/vehicle_agent.tscn"
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var resource: Resource = load(VehicleScenePath)
    if not (resource is PackedScene):
        _fail("vehicle_agent.tscn did not parse into a PackedScene")
        return
    var instance: Node = (resource as PackedScene).instantiate()
    if not instance is CivicVehicleAgent:
        if is_instance_valid(instance):
            instance.free()
        _fail("vehicle scene root is missing the CivicVehicleAgent script")
        return
    var vehicle: CivicVehicleAgent = instance as CivicVehicleAgent
    root.add_child(vehicle)
    var body: StaticBody3D = vehicle.get_node_or_null("CollisionBody") as StaticBody3D
    if body == null or body.collision_layer != 4:
        _fail("vehicle scene lacks its layer-4 static collision body")
        return
    var collision: CollisionShape3D = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collision == null or not (collision.shape is BoxShape3D):
        _fail("vehicle scene collider is missing its box geometry")
        return
    var shape: BoxShape3D = collision.shape as BoxShape3D
    if shape.size.x <= 0.1 or shape.size.z <= 0.1:
        _fail("vehicle scene collision box has invalid dimensions")
        return
    if vehicle.get_node_or_null("Visual") == null or vehicle.get_node_or_null("Cabin") == null:
        _fail("vehicle scene is missing render children")
        return
    for wheel_name in ["Wheel_L_Front", "Wheel_L_Rear", "Wheel_R_Front", "Wheel_R_Rear"]:
        if not (vehicle.get_node_or_null(wheel_name) is MeshInstance3D):
            _fail("vehicle scene missing wheel %s" % wheel_name)
            return
    var road := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 11
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -20)])
    road.add_lane(lane)
    if not vehicle.configure(road, PackedInt32Array([11]), Profile.new()):
        _fail("vehicle scene root could not configure a legal single-lane route")
        return
    if not vehicle.active or vehicle.route.size() != 1 or vehicle.road_graph != road:
        _fail("configured vehicle lost its route or active status")
        return
    # Collision probes and visual feedback are tested independently; no
    # physical-space query is attempted from a nonphysics callback.
    vehicle.queue_free()
    print("CIVIC_CHAOS_VEHICLE_SCENE_CONTRACT_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
