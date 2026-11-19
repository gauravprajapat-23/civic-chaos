extends SceneTree
## CAR-ART-05C: cosmetic sedan exterior redesign cannot change vehicle
## collision, route movement, glass count, brake cues or lane paint variants.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var car := CarScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("vehicle scene unavailable")
        return
    root.add_child(car)
    var details := car.get_node("DetailVisuals") as CivicVehicleVisuals
    var collision := car.get_node("CollisionBody/CollisionShape3D") as CollisionShape3D
    var body := car.get_node("CollisionBody") as StaticBody3D
    if details == null or body.collision_layer != 4 or not (collision.shape is BoxShape3D) or (collision.shape as BoxShape3D).size != Vector3(1.6, 1.2, 3.0):
        _fail("original authoritative layer-4 car collider changed")
        return
    for name in ["GrilleSurroundTop", "GrilleSurroundBottom", "GrilleSide_L",
            "GrilleSide_R", "RearTrunkLip", "RearTailPanel", "RearLowerValance"]:
        if not (details.get_node_or_null(name) is MeshInstance3D):
            _fail("missing exterior redesign element " + name)
            return
    for side in ["L", "R"]:
        for name in ["FrontDoorLowerLine_", "RearDoorLowerLine_",
                "FrontDoorHandle_", "RearDoorHandle_"]:
            if not (details.get_node_or_null(name + side) is MeshInstance3D):
                _fail("door styling missing " + name + side)
                return
        for axle in ["Front", "Rear"]:
            var face := details.get_node_or_null(axle + "WheelFace_" + side) as MeshInstance3D
            if face == null or not (face.mesh is CylinderMesh):
                _fail("wheel face missing " + axle + side)
                return
            if absf(face.position.y - 0.36) > 0.001 or absf(face.position.z - (-0.95 if axle == "Front" else 0.95)) > 0.001:
                _fail("wheel face does not align with original wheel axle")
                return
            var spoke_count: int = 0
            for number in range(5):
                var spoke := details.get_node_or_null("%sWheelSpoke_%s_%d" % [axle, side, number]) as MeshInstance3D
                if spoke == null or not (spoke.mesh is BoxMesh):
                    _fail("wheel spoke missing on " + axle + side)
                    return
                if spoke.position.distance_to(face.position) > 0.23:
                    _fail("wheel spoke extends beyond wheel face")
                    return
                spoke_count += 1
            if spoke_count != 5:
                _fail("incorrect wheel spoke count")
                return
    var transparent_count: int = 0
    for item in details.get_children():
        if item is CollisionObject3D or item is CollisionShape3D:
            _fail("cosmetic exterior added collision objects")
            return
        if item is MeshInstance3D:
            var finish := (item as MeshInstance3D).material_override as StandardMaterial3D
            if finish != null and finish.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
                transparent_count += 1
    if transparent_count != 6:
        _fail("car redesign changed six-pane glass budget")
        return
    details.set_braking(true)
    var lamp := details.get_node("RearLamp_L") as MeshInstance3D
    var lamp_mat := lamp.material_override as StandardMaterial3D
    if lamp_mat == null or lamp_mat.emission.r < 0.8:
        _fail("brake lamps regressed")
        return
    details.set_braking(false)
    if lamp_mat.emission.r >= 0.8:
        _fail("brake lamps did not release")
        return
    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 1
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -30)])
    graph.add_lane(lane)
    if not car.configure(graph, PackedInt32Array([1]), Profile.new()):
        _fail("redesigned car cannot follow an unchanged route")
        return
    var color: int = details.color_variant()
    var start: Vector3 = car.global_position
    car.physics_obstacle_checks_enabled = false
    for i in range(30):
        car.advance_fixed(0.05)
    if car.global_position.distance_to(start) <= 0.15 or details.color_variant() != color:
        _fail("exterior styling changed motion or paint variant")
        return
    car.queue_free()
    print("CIVIC_CHAOS_CAR_ART_05C_EXTERIOR_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
