extends SceneTree
## CAR-ART-04B/C: visual-only cabin and inset side mirror geometry.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var car: CivicVehicleAgent = CarScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("vehicle scene did not load")
        return
    root.add_child(car)
    var details: CivicVehicleVisuals = car.get_node("DetailVisuals") as CivicVehicleVisuals
    var cabin: MeshInstance3D = car.get_node("Cabin") as MeshInstance3D
    if not (cabin.mesh is ArrayMesh):
        _fail("enclosed cabin lacks its tapered mesh")
        return
    var roof: MeshInstance3D = details.get_node("Roof") as MeshInstance3D
    if roof.position.y < 1.24 or roof.position.y > 1.34:
        _fail("roof has an implausible height")
        return
    var left: MeshInstance3D = details.get_node("Mirror_L") as MeshInstance3D
    var right: MeshInstance3D = details.get_node("Mirror_R") as MeshInstance3D
    for side in ["L", "R"]:
        var mount: MeshInstance3D = details.get_node_or_null("MirrorMount_" + side) as MeshInstance3D
        var housing: MeshInstance3D = details.get_node_or_null("Mirror_" + side) as MeshInstance3D
        var glass: MeshInstance3D = details.get_node_or_null("MirrorGlass_" + side) as MeshInstance3D
        if mount == null or housing == null or glass == null:
            _fail("mirror assembly incomplete on " + side)
            return
        if not (housing.mesh is BoxMesh) or not (glass.mesh is BoxMesh):
            _fail("mirror assembly contains invalid geometry")
            return
        var mirror_size: Vector3 = (housing.mesh as BoxMesh).size
        if mirror_size.x > 0.18 or mirror_size.y > 0.13 or mirror_size.z > 0.20:
            _fail("oversized mirror still extends from the door")
            return
        if absf(housing.position.x) > 0.90 or absf(mount.position.x) > 0.80:
            _fail("mirror is detached from front door")
            return
        if absf(glass.position.x - housing.position.x) > 0.03 or glass.position.z <= housing.position.z:
            _fail("mirror glass is not inset on rear-facing housing")
            return
        var glass_material: StandardMaterial3D = glass.material_override as StandardMaterial3D
        var casing_material: StandardMaterial3D = housing.material_override as StandardMaterial3D
        if glass_material == null or casing_material == null or glass_material == casing_material:
            _fail("mirror uses flat black casing instead of glass")
            return
        if glass_material.metallic < 0.4 or glass_material.albedo_color.r < 0.35:
            _fail("mirror glass lacks readable pale reflective appearance")
            return
        var window: MeshInstance3D = details.get_node("FrontSideWindow_" + side) as MeshInstance3D
        if window.material_override == glass.material_override or absf(window.position.x) > 0.70:
            _fail("side window material or position is incorrect")
            return
    if not is_equal_approx(left.position.x, -right.position.x) or not is_equal_approx(left.position.z, right.position.z):
        _fail("mirrors are not symmetric")
        return
    var collision: CollisionShape3D = car.get_node("CollisionBody/CollisionShape3D") as CollisionShape3D
    if not (collision.shape is BoxShape3D) or (collision.shape as BoxShape3D).size != Vector3(1.6, 1.2, 3.0):
        _fail("car styling modified collision geometry")
        return
    for piece in details.get_children():
        if piece is CollisionObject3D or piece is CollisionShape3D:
            _fail("decorative mesh introduced a collision body")
            return
    car.queue_free()
    print("CIVIC_CHAOS_CAR_ART_04BC_VISUAL_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
