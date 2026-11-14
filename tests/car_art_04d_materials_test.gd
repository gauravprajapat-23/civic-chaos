extends SceneTree
## CAR-ART-04D: PBR material identity, wheel finish and cosmetic isolation.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _mat(item: Node) -> StandardMaterial3D:
    if not (item is MeshInstance3D):
        return null
    return (item as MeshInstance3D).material_override as StandardMaterial3D

func _run() -> void:
    var car: CivicVehicleAgent = CarScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("car scene could not instantiate")
        return
    root.add_child(car)
    var detail: CivicVehicleVisuals = car.get_node("DetailVisuals") as CivicVehicleVisuals
    var paint := _mat(car.get_node("Visual"))
    var windshield := _mat(detail.get_node("Windscreen"))
    var mirror := _mat(detail.get_node("MirrorGlass_L"))
    var housing := _mat(detail.get_node("Mirror_L"))
    var metal := _mat(detail.get_node("FrontBumper"))
    var hub := _mat(detail.get_node("FrontHub_L"))
    var tire := _mat(car.get_node("Wheel_L_Front"))
    var headlamp := _mat(detail.get_node("FrontLamp_L"))
    var taillamp := _mat(detail.get_node("RearLamp_L"))
    if paint == null or windshield == null or mirror == null or housing == null or metal == null or hub == null or tire == null or headlamp == null or taillamp == null:
        _fail("one or more automotive materials missing")
        return
    if not paint.clearcoat_enabled or paint.clearcoat < 0.3 or paint.roughness > 0.48:
        _fail("car paint lacks restrained clearcoat finish")
        return
    if paint.metallic < 0.10 or paint.metallic > 0.45:
        _fail("car paint has unrealistic metallic intensity")
        return
    if paint == windshield or windshield == mirror or mirror == housing or metal == hub or hub == tire:
        _fail("body paint, window, mirror casing, glass, hub and tire must use separate finishes")
        return
    if windshield.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mirror.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
        _fail("expensive transparent car glass was introduced in Android traffic")
        return
    if mirror.metallic < 0.4 or mirror.albedo_color.r < 0.35:
        _fail("mirror glass is dark and indistinct")
        return
    if tire.metallic > 0.02 or tire.roughness < 0.82 or hub.metallic < 0.4:
        _fail("wheel hub/tire shading is incorrect")
        return
    if not headlamp.emission_enabled or not taillamp.emission_enabled:
        _fail("safety lamps lost their light cues")
        return
    var original: Color = paint.albedo_color
    detail.set_lane_variant(1)
    var variant_one: Color = paint.albedo_color
    detail.set_lane_variant(2)
    if paint.albedo_color == variant_one:
        _fail("lane-based palette has no visible variation")
        return
    detail.set_lane_variant(1)
    if paint.albedo_color != variant_one:
        _fail("same route lane selected a different color")
        return
    detail.set_lane_variant(0)
    if paint.albedo_color != original:
        _fail("palette failed to restore the base paint")
        return
    detail.set_braking(true)
    if taillamp.emission.r < 0.8:
        _fail("brake lights failed to brighten")
        return
    detail.set_braking(false)
    if taillamp.emission.r >= 0.8:
        _fail("brake lights failed to dim")
        return
    var collision := car.get_node("CollisionBody/CollisionShape3D") as CollisionShape3D
    if collision == null or not (collision.shape is BoxShape3D) or (collision.shape as BoxShape3D).size != Vector3(1.6, 1.2, 3.0):
        _fail("visual shading change mutated the vehicle collision footprint")
        return
    for item in detail.get_children():
        if item is CollisionShape3D or item is CollisionObject3D:
            _fail("car materials introduced a physical collision object")
            return
    car.queue_free()
    print("CIVIC_CHAOS_CAR_ART_04D_MATERIALS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
