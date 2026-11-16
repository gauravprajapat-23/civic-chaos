extends SceneTree
## CAR-ART-05B: cabin remains visibly open, body solid, glass minimal,
## upper driver unobscured and every extra piece non-colliding.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var car := CarScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("missing physical vehicle scene")
        return
    root.add_child(car)
    var details := car.get_node_or_null("DetailVisuals") as CivicVehicleVisuals
    var shell := car.get_node_or_null("Cabin") as MeshInstance3D
    if details == null or shell == null or not (shell.mesh is ArrayMesh):
        _fail("vehicle cabin missing proper tapered geometry")
        return
    var body_material := shell.material_override as StandardMaterial3D
    if body_material == null or body_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
        _fail("full transparent cabin causes overlapping glass and sorting")
        return
    var mesh := shell.mesh as ArrayMesh
    var arrays: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    if vertices.is_empty():
        _fail("cabin has no mesh geometry")
        return
    for vertex in vertices:
        # Upper body/window space must be open: local Y 0.225 used to
        # form a sealed six-sided shell; new belt ends at -0.095.
        if vertex.y > -0.09:
            _fail("opaque cabin still covers the actual window opening")
            return
    var roof := details.get_node_or_null("Roof") as MeshInstance3D
    var head := details.get_node_or_null("DriverHead") as MeshInstance3D
    var headrest := details.get_node_or_null("HeadRest_R") as MeshInstance3D
    if roof == null or head == null or headrest == null:
        _fail("roof, driver or seat support missing")
        return
    var roof_bottom: float = roof.position.y - (roof.mesh as BoxMesh).size.y * 0.5
    var head_top: float = head.position.y + (head.mesh as SphereMesh).radius
    var rest_top: float = headrest.position.y + (headrest.mesh as BoxMesh).size.y * 0.5
    if head_top >= roof_bottom or rest_top >= roof_bottom:
        _fail("driver or front seat protrudes through solid roof")
        return
    for name in [
        "RoofFrontLip", "RoofRearLip",
        "FrontSideWindow_L", "FrontSideWindow_R",
        "RearSideWindow_L", "RearSideWindow_R",
        "WindowSill_L", "WindowSill_R",
        "HoodShoulder_L", "HoodShoulder_R",
        "TrunkShoulder_L", "TrunkShoulder_R",
        "FrontLampBrow_L", "FrontLampBrow_R",
        "RearLampBorder_L", "RearLampBorder_R"
    ]:
        if not (details.get_node_or_null(name) is MeshInstance3D):
            _fail("missing polished car component: " + name)
            return
    var glass_count: int = 0
    for child in details.get_children():
        if child is CollisionObject3D or child is CollisionShape3D:
            _fail("cosmetic redesign changed traffic collision volumes")
            return
        if child is MeshInstance3D:
            var finish := (child as MeshInstance3D).material_override as StandardMaterial3D
            if finish != null and finish.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
                glass_count += 1
                if not str(child.name).contains("Glass") and not str(child.name).contains("Window") and str(child.name) != "Windscreen":
                    _fail("non-window mesh introduced unnecessary transparency: " + str(child.name))
                    return
    if glass_count != 6:
        _fail("expected exactly six single-layer glass panes, got " + str(glass_count))
        return
    var collision := car.get_node("CollisionBody/CollisionShape3D") as CollisionShape3D
    var body := car.get_node("CollisionBody") as StaticBody3D
    if body.collision_layer != 4 or not (collision.shape is BoxShape3D) or (collision.shape as BoxShape3D).size != Vector3(1.6, 1.2, 3.0):
        _fail("cosmetic polish modified car physics or collision layer")
        return
    car.queue_free()
    print("CIVIC_CHAOS_CAR_ART_05B_CABIN_POLISH_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
