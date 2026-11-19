extends SceneTree
## VEHICLE-RIDE-02: motorcycles must roll vertically in their travel
## plane, NOT yaw horizontally around the road's up axis.
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var bike := Bike.new() as CivicRideableBike
    root.add_child(bike)
    var front := bike.find_child("FrontWheel", true, false) as MeshInstance3D
    var rear := bike.find_child("RearWheel", true, false) as MeshInstance3D
    if front == null or rear == null:
        _fail("both physical wheel visuals are required")
        return
    # animate_wheels() rotates BOTH wheels. Capture BOTH initial states
    # before calling it once; the old test incorrectly advanced both wheels
    # separately per wheel, leaving the second wheel at 180 degrees.
    var wheels: Array[MeshInstance3D] = [front, rear]
    var before_bases: Array[Basis] = []
    var before_positions: Array[Vector3] = []
    for wheel in wheels:
        if wheel.get_node_or_null("RollingSpoke") == null:
            _fail("wheel needs a visible spoke to show true rolling motion")
            return
        var original_basis: Basis = wheel.transform.basis
        var original_axle: Vector3 = (original_basis * Vector3.UP).normalized()
        if absf(original_axle.dot(Vector3.UP)) > 0.01 or absf(original_axle.dot(Vector3.RIGHT)) < 0.99:
            _fail("wheel axle is not horizontal and perpendicular to bike travel")
            return
        before_bases.append(original_basis)
        before_positions.append(wheel.position)

    bike.animate_wheels(0.43 * PI * 0.5)
    for index in range(wheels.size()):
        var wheel: MeshInstance3D = wheels[index]
        var original_basis: Basis = before_bases[index]
        var original_axle: Vector3 = (original_basis * Vector3.UP).normalized()
        var original_radial: Vector3 = (original_basis * Vector3.FORWARD).normalized()
        var axle_after: Vector3 = (wheel.transform.basis * Vector3.UP).normalized()
        var radial_after: Vector3 = (wheel.transform.basis * Vector3.FORWARD).normalized()
        if original_axle.distance_to(axle_after) > 0.001:
            _fail("wheel is wobbling/yawing instead of rotating about its axle")
            return
        if absf(original_radial.dot(radial_after)) > 0.01:
            _fail("wheel did not roll by 90 degrees for a quarter circumference")
            return
        if absf(radial_after.y) < 0.99:
            _fail("rolling motion is horizontal rather than vertical")
            return
        if wheel.position.distance_to(before_positions[index]) > 0.0001:
            _fail("wheel center moved while spinning")
            return
    # Stationary player must not get cosmetic rotation.
    var stationary_basis: Basis = front.transform.basis
    bike.animate_wheels(0.0)
    if not front.transform.basis.is_equal_approx(stationary_basis):
        _fail("parked wheel keeps rotating without travel")
        return
    bike.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_02_WHEEL_ROLL_AXIS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
