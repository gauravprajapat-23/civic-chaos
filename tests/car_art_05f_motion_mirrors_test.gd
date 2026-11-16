extends SceneTree
## CAR-ART-05F: readable mirror housings, no protruding roof bars and
## wheel/steering motion based on accepted travel only.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var car := CarScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("car scene could not load")
        return
    root.add_child(car)
    var visual := car.get_node("DetailVisuals") as CivicVehicleVisuals
    if visual == null:
        _fail("missing visuals")
        return
    for side in ["L", "R"]:
        var housing := visual.get_node("Mirror_" + side) as MeshInstance3D
        var glass := visual.get_node("MirrorGlass_" + side) as MeshInstance3D
        if housing == null or glass == null or absf(housing.position.x) < 0.82 or glass.position.z <= housing.position.z:
            _fail("side mirrors not projected or glass not rear-facing")
            return
        var mirror_material := glass.material_override as StandardMaterial3D
        if mirror_material == null or mirror_material.metallic < 0.40:
            _fail("mirror finish unreadable")
            return
    for name in ["RoofFrontLip", "RoofRearLip"]:
        var lip := visual.get_node(name) as MeshInstance3D
        var roof := visual.get_node("Roof") as MeshInstance3D
        if lip == null or lip.material_override != roof.material_override:
            _fail("dark raised roof cage artifact remains")
            return
        if lip.position.y > roof.position.y:
            _fail("roof trim sticks out above roof")
            return
    var start_heading := (car.get_node("Wheel_L_Front") as MeshInstance3D).rotation.x
    visual.update_motion_visuals(0.8, 0.09)
    var front := car.get_node("Wheel_L_Front") as MeshInstance3D
    var rear := car.get_node("Wheel_L_Rear") as MeshInstance3D
    var steering := visual.get_node("SteeringWheel") as MeshInstance3D
    if absf(front.rotation.x - start_heading) < 0.05 or absf(rear.rotation.x - start_heading) < 0.05:
        _fail("visual tires do not rotate when car moves")
        return
    if front.rotation.y <= 0.0 or steering.rotation.z <= 0.0:
        _fail("turning input not represented in cosmetic steering")
        return
    var group := visual.get_node("BatchedWheelSpokes") as MultiMeshInstance3D
    if group == null or group.multimesh == null or group.multimesh.instance_count != 20:
        _fail("batched wheel spokes missing")
        return
    var before: Array[Transform3D] = []
    for i in range(group.multimesh.instance_count):
        before.append(group.multimesh.get_instance_transform(i))
    visual.update_motion_visuals(0.3, -0.08)
    var moved: int = 0
    var max_shift: float = 0.0
    for i in range(group.multimesh.instance_count):
        var after: Transform3D = group.multimesh.get_instance_transform(i)
        var shift: float = before[i].origin.distance_to(after.origin)
        max_shift = maxf(max_shift, shift)
        if shift > 0.01:
            moved += 1
    if moved < 16:
        _fail("batched spokes failed to rotate: changed=%d/20 max_shift=%.4f current_lod=%d" % [
            moved, max_shift, visual.detail_level()])
        return
    if front.rotation.y >= 0.0:
        _fail("front tires failed to reverse cosmetic steering")
        return
    var stopped_angle: float = front.rotation.x
    visual.update_motion_visuals(0.0, 0.0)
    if absf(front.rotation.x - stopped_angle) > 0.0001:
        _fail("stationary car is spinning its tires")
        return
    var collision := car.get_node("CollisionBody/CollisionShape3D") as CollisionShape3D
    if not (collision.shape is BoxShape3D) or (collision.shape as BoxShape3D).size != Vector3(1.6, 1.2, 3.0):
        _fail("visual work modified physics collider")
        return
    for child in visual.get_children():
        if child is CollisionShape3D or child is CollisionObject3D:
            _fail("visual animation created physical collision")
            return
    var road := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 1
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0,0,-30)])
    if not road.add_lane(lane) or not car.configure(road, PackedInt32Array([1]), Profile.new()):
        _fail("car cannot configure regular route")
        return
    car.physics_obstacle_checks_enabled = false
    var original: Vector3 = car.global_position
    for i in range(25):
        car.advance_fixed(0.05)
    if car.global_position.distance_to(original) < 0.05:
        _fail("cosmetic movement changes blocked car travel")
        return
    car.queue_free()
    print("CIVIC_CHAOS_CAR_ART_05F_MOTION_MIRRORS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
