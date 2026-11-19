extends SceneTree
## CAR-ART-05E: visual-only multi-mesh batching + reversible distance LOD.
## No collision, simulation, paint-identity or checkpoint mutation.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var car := CarScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("car scene unavailable")
        return
    root.add_child(car)
    var details := car.get_node_or_null("DetailVisuals") as CivicVehicleVisuals
    if details == null:
        _fail("visual controller missing")
        return
    var spokes: Array[MeshInstance3D] = []
    for child in details.get_children():
        if child is MeshInstance3D and str(child.name).contains("WheelSpoke_"):
            spokes.append(child as MeshInstance3D)
    if spokes.size() != 20:
        _fail("20 legacy wheel-spoke nodes not preserved")
        return
    var batched := details.get_node_or_null("BatchedWheelSpokes") as MultiMeshInstance3D
    if batched == null or batched.multimesh == null or batched.multimesh.instance_count != 20:
        _fail("wheel spokes were not combined into one draw group")
        return
    if not (batched.multimesh.mesh is BoxMesh):
        _fail("batched spokes use an unexpected mesh")
        return
    for spoke in spokes:
        if spoke.visible:
            _fail("individual spoke still produces duplicate draw calls")
            return
    if details.detail_level() != CivicVehicleVisuals.DETAIL_NEAR or not batched.visible:
        _fail("nearby car does not expose its complete wheel batch")
        return
    var head := details.get_node("DriverHead") as MeshInstance3D
    var roof := details.get_node("Roof") as MeshInstance3D
    var glass := details.get_node("Windscreen") as MeshInstance3D
    var lamp := details.get_node("RearLamp_L") as MeshInstance3D
    var badge := details.get_node("FrontBadge") as MeshInstance3D
    details.update_lod_distance(40.0)
    if details.detail_level() != CivicVehicleVisuals.DETAIL_MID or not head.visible or not roof.visible or not glass.visible or badge.visible or batched.visible:
        _fail("mid-detail did not hide small items while retaining driver")
        return
    details.update_lod_distance(26.0)
    if details.detail_level() != CivicVehicleVisuals.DETAIL_MID:
        _fail("LOD oscillates in near/mid hysteresis band")
        return
    details.update_lod_distance(62.0)
    if details.detail_level() != CivicVehicleVisuals.DETAIL_FAR or head.visible or glass.visible or not roof.visible or not lamp.visible:
        _fail("far level did not preserve road silhouette and lamps")
        return
    details.update_lod_distance(53.0)
    if details.detail_level() != CivicVehicleVisuals.DETAIL_FAR:
        _fail("LOD oscillates in mid/far hysteresis band")
        return
    details.update_lod_distance(12.0)
    if details.detail_level() != CivicVehicleVisuals.DETAIL_NEAR or not head.visible or not roof.visible or not glass.visible or not badge.visible or not batched.visible:
        _fail("full detail did not reappear when car approached")
        return
    for spoke in spokes:
        if spoke.visible:
            _fail("near distance re-enabled redundant individual spokes")
            return

    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 21
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -30)])
    if not graph.add_lane(lane) or not car.configure(graph, PackedInt32Array([21]), Profile.new()):
        _fail("car graph/route invalid")
        return
    var identity: Dictionary = details.visual_identity().duplicate(true)
    var layer: int = (car.get_node("CollisionBody") as StaticBody3D).collision_layer
    var size: Vector3 = ((car.get_node("CollisionBody/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size
    car.physics_obstacle_checks_enabled = false
    var before: Vector3 = car.global_position
    for step in range(20):
        car.advance_fixed(0.05)
    if before.distance_to(car.global_position) <= 0.05:
        _fail("car could not drive after visual LOD adjustments")
        return
    if layer != 4 or size != Vector3(1.6, 1.2, 3.0) or details.visual_identity() != identity:
        _fail("LOD mutated authoritative physics or lane-derived identity")
        return
    var spawner := Spawner.new() as CivicTrafficSpawner
    root.add_child(spawner)
    spawner.active_vehicles.append(car)
    spawner.update_fleet_visual_lod(car.global_position + Vector3(0, 0, 90))
    if details.detail_level() != CivicVehicleVisuals.DETAIL_FAR:
        _fail("fleet-level update failed to assign far LOD")
        return
    spawner.update_fleet_visual_lod(car.global_position)
    if details.detail_level() != CivicVehicleVisuals.DETAIL_NEAR:
        _fail("fleet-level update did not restore near detail")
        return
    spawner.active_vehicles.clear()
    spawner.queue_free()
    car.queue_free()
    print("CIVIC_CHAOS_CAR_ART_05E_MOBILE_LOD_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
