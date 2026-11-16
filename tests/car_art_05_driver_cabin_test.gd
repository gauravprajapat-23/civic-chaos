extends SceneTree
## CAR-ART-05: a visible right-hand-drive character within the real
## vehicle scene, no extra colliders or simulation changes.
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Builder = preload("res://scripts/world/junction_builder.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var car: CivicVehicleAgent = VehicleScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("traffic scene did not instantiate")
        return
    root.add_child(car)
    var visuals: CivicVehicleVisuals = car.get_node_or_null("DetailVisuals") as CivicVehicleVisuals
    if visuals == null:
        _fail("vehicle has no detail visuals")
        return
    var cabin := car.get_node_or_null("Cabin") as MeshInstance3D
    var windshield := visuals.get_node_or_null("Windscreen") as MeshInstance3D
    if cabin == null or windshield == null:
        _fail("cabin glazing missing")
        return
    var glass: StandardMaterial3D = windshield.material_override as StandardMaterial3D
    var shell: StandardMaterial3D = cabin.material_override as StandardMaterial3D
    if glass == null or shell == null or glass.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA or shell.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
        _fail("windshield must be transparent, lower cabin shell must be solid paint")
        return
    if glass.albedo_color.a > 0.60 or glass.albedo_color.a < 0.15:
        _fail("driver window tint is unusable")
        return
    for part in ["DriverHead", "DriverNeck", "DriverTorso", "DriverHair",
            "DriverArm_-1", "DriverArm_1", "FrontSeat_R",
            "FrontSeat_L", "Dashboard", "SteeringWheel",
            "WindshieldPillar_-1", "WindshieldPillar_1"]:
        if not (visuals.get_node_or_null(part) is MeshInstance3D):
            _fail("real driver/cockpit mesh missing: " + part)
            return
    var head: MeshInstance3D = visuals.get_node("DriverHead") as MeshInstance3D
    var wheel: MeshInstance3D = visuals.get_node("SteeringWheel") as MeshInstance3D
    if head.position.x < 0.20 or wheel.position.x < 0.20:
        _fail("driver should be at the right-hand seat in Indian traffic")
        return
    if head.position.y + 0.105 >= 1.283 - 0.041:
        _fail("driver head clips into or through roof")
        return
    if not (wheel.mesh is TorusMesh) or wheel.position.distance_to(head.position) > 0.9:
        _fail("steering wheel does not sit in driving position")
        return
    for item in visuals.get_children():
        if item is CollisionObject3D or item is CollisionShape3D:
            _fail("decorative occupant changed collision or traffic safety")
            return
    var body: StaticBody3D = car.get_node("CollisionBody") as StaticBody3D
    var shape: CollisionShape3D = car.get_node("CollisionBody/CollisionShape3D") as CollisionShape3D
    if body.collision_layer != 4 or not (shape.shape is BoxShape3D) or (shape.shape as BoxShape3D).size != Vector3(1.6, 1.2, 3.0):
        _fail("driver art changed authoritative car physics footprint")
        return
    var graph: CivicRoadGraph = Builder.make_test_graph()
    if not car.configure(graph, PackedInt32Array([1, 4]), Profile.new()):
        _fail("car with driver could not configure unchanged route")
        return
    var old_variant: int = visuals.color_variant()
    var initial: Vector3 = car.global_position
    car.physics_obstacle_checks_enabled = false
    for i in range(25):
        car.advance_fixed(0.05)
    if car.global_position.distance_to(initial) <= 0.1:
        _fail("interior meshes prevented routine vehicle movement")
        return
    if visuals.color_variant() != old_variant:
        _fail("driver/interior changed paint variant RNG")
        return
    car.queue_free()
    print("CIVIC_CHAOS_CAR_ART_05_DRIVER_CABIN_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
