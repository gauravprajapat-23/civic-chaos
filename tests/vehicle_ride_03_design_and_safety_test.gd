extends SceneTree
## VEHICLE-RIDE-03: richer motorcycle styling remains visual-only,
## with correct signed wheel rotation and light feedback.
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var bike := Bike.new() as CivicRideableBike
    root.add_child(bike)
    var required: Array[String] = [
        "FrontWheel", "RearWheel", "FuelTank", "Seat", "Handlebar",
        "Headlight", "TailLight", "EngineBlock", "ExhaustPipe",
        "FrontMudguard", "RearMudguard", "FrontNumberPlate",
        "MirrorGlass_-1", "MirrorGlass_1", "RearGrabRail",
        "SidePanelLeft", "SidePanelRight"
    ]
    for name in required:
        var visual := bike.find_child(name, true, false)
        if visual == null or not (visual is MeshInstance3D):
            _fail("Missing recognizable motorcycle part: " + name)
            return
        if visual is CollisionObject3D:
            _fail("decorative body unexpectedly blocks the road")
            return
    if bike.collision_layer != 16 or bike.collision_mask != 0:
        _fail("parked motorcycle changed its nonblocking interaction layer")
        return
    var collider := bike.get_node_or_null("InteractionShape") as CollisionShape3D
    if collider == null or collider.shape == null:
        _fail("parked motorcycle lost its USE interaction shape")
        return
    var rear := bike.find_child("RearWheel", true, false) as MeshInstance3D
    var front := bike.find_child("FrontWheel", true, false) as MeshInstance3D
    var front_at_rest: Basis = front.transform.basis
    bike.animate_wheels(0.43)
    var after_forward: float = bike._wheel_roll_total
    if not is_equal_approx(after_forward, 1.0):
        _fail("forward travel produced incorrect wheel angle")
        return
    bike.animate_wheels(-0.43)
    if absf(bike._wheel_roll_total) > 0.0001 or not front.transform.basis.is_equal_approx(front_at_rest):
        _fail("backward travel did not undo real forward wheel rotation")
        return
    if not rear.transform.basis.is_equal_approx(front.transform.basis):
        _fail("front and rear wheels spin at different rates")
        return
    var brake := bike.find_child("TailLight", true, false) as MeshInstance3D
    bike.set_braking(true)
    var mat := brake.material_override as StandardMaterial3D
    if mat == null or not mat.emission_enabled:
        _fail("braking failed to illuminate tail light")
        return
    bike.set_braking(false)
    if mat.emission_enabled:
        _fail("tail light remained illuminated after releasing brake")
        return
    bike.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_03_DESIGN_AND_SAFETY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
