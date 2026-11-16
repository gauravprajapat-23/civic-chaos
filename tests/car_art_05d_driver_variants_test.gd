extends SceneTree
## CAR-ART-05D: driver's appearance and cabin trim are deterministic
## cosmetic functions of first route lane. No RNG or save schema required.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var graph := Graph.new()
    for id in range(15, 20):
        var lane := Lane.new()
        lane.lane_id = id
        lane.centerline = PackedVector3Array([
            Vector3(float(id) * 10.0, 0, 0),
            Vector3(float(id) * 10.0, 0, -30)
        ])
        if not graph.add_lane(lane):
            _fail("test lane graph could not be built")
            return
    var seen_shirts: Dictionary = {}
    var seen_paints: Dictionary = {}
    for id in range(15, 20):
        var first := CarScene.instantiate() as CivicVehicleAgent
        var restored := CarScene.instantiate() as CivicVehicleAgent
        if first == null or restored == null:
            _fail("vehicle scene could not instantiate")
            return
        root.add_child(first)
        root.add_child(restored)
        var route := PackedInt32Array([id])
        if not first.configure(graph, route, Profile.new()) or not restored.configure(graph, route, Profile.new()):
            _fail("two identical saved routes not accepted")
            return
        var visual := first.get_node("DetailVisuals") as CivicVehicleVisuals
        var replica := restored.get_node("DetailVisuals") as CivicVehicleVisuals
        var expected_driver: int = posmod(id * 7 + 3, 5)
        if visual.driver_variant() != expected_driver or replica.driver_variant() != expected_driver:
            _fail("driver identity not deterministic for lane " + str(id))
            return
        if visual.color_variant() != posmod(id, 5):
            _fail("established body-paint choice changed")
            return
        var a: Dictionary = visual.visual_identity()
        var b: Dictionary = replica.visual_identity()
        if a != b:
            _fail("identical route reconstructed a different driver")
            return
        for node_name in ["DriverTorso", "DriverHead", "DriverHair", "FrontSeat_R", "FrontHub_R"]:
            var left := visual.get_node(node_name) as MeshInstance3D
            var right := replica.get_node(node_name) as MeshInstance3D
            if left == null or right == null:
                _fail("driver variant removed mesh " + node_name)
                return
            var ml := left.material_override as StandardMaterial3D
            var mr := right.material_override as StandardMaterial3D
            if ml == null or mr == null or ml.albedo_color != mr.albedo_color:
                _fail("same saved route returned inconsistent character finish")
                return
        var shirt := visual.get_node("DriverTorso") as MeshInstance3D
        var hair := visual.get_node("DriverHair") as MeshInstance3D
        var shirt_color: Color = (shirt.material_override as StandardMaterial3D).albedo_color
        seen_shirts[shirt_color.to_html()] = true
        seen_paints[visual.color_variant()] = true
        var original_material: Material = shirt.material_override
        var original_identity: Dictionary = visual.visual_identity()
        visual.set_lane_variant(id)
        if shirt.material_override != original_material or visual.visual_identity() != original_identity:
            _fail("reapplication changed identity or allocated replacement materials")
            return
        if hair.scale.x < 1.0 or hair.scale.x > 1.2:
            _fail("hair variant escaped conservative cabin silhouette")
            return
        var collision := first.get_node("CollisionBody/CollisionShape3D") as CollisionShape3D
        if not (collision.shape is BoxShape3D) or (collision.shape as BoxShape3D).size != Vector3(1.6, 1.2, 3.0):
            _fail("driver variant changed physical collision volume")
            return
        if (first.get_node("CollisionBody") as StaticBody3D).collision_layer != 4:
            _fail("driver variant changed traffic collision layer")
            return
        for cosmetic in visual.get_children():
            if cosmetic is CollisionObject3D or cosmetic is CollisionShape3D:
                _fail("driver variant added a physics collider")
                return
        first.queue_free()
        restored.queue_free()
    if seen_shirts.size() != 5 or seen_paints.size() != 5:
        _fail("five lane choices did not produce five distinct appearances")
        return
    print("CIVIC_CHAOS_CAR_ART_05D_DRIVER_VARIANTS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
