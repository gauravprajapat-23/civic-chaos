extends SceneTree
## ART-CAR-01: actual traffic scene gets proper car detail without changing
## the collision box, deterministic route physics or traffic RNG.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var road := Graph.new()
    for id in [11, 12]:
        var lane := Lane.new()
        lane.lane_id = id
        lane.centerline = PackedVector3Array([
            Vector3(0, 0, 0), Vector3(0, 0, -30)
        ])
        if not road.add_lane(lane):
            _fail("vehicle test lane unavailable")
            return
    var car: CivicVehicleAgent = CarScene.instantiate() as CivicVehicleAgent
    if car == null:
        _fail("vehicle scene did not instantiate as a CivicVehicleAgent")
        return
    root.add_child(car)
    var body: StaticBody3D = car.get_node("CollisionBody") as StaticBody3D
    var shape: CollisionShape3D = body.get_node("CollisionShape3D") as CollisionShape3D
    if body.collision_layer != 4 or not (shape.shape is BoxShape3D):
        _fail("original traffic collision contract was modified")
        return
    if (shape.shape as BoxShape3D).size != Vector3(1.6, 1.2, 3.0):
        _fail("visual redesign changed authoritative traffic footprint")
        return
    var details: CivicVehicleVisuals = car.get_node_or_null("DetailVisuals") as CivicVehicleVisuals
    if details == null or details.get_child_count() < 22:
        _fail("detailed car mesh not attached to vehicle scene")
        return
    for piece_name in [
        "Hood", "Trunk", "Roof", "Windscreen", "RearGlass",
        "FrontSideWindow_L", "FrontSideWindow_R",
        "FrontGrille", "FrontLamp_L", "RearLamp_R",
        "FrontHub_L", "RearHub_R", "Mirror_L"
    ]:
        if not (details.get_node_or_null(piece_name) is MeshInstance3D):
            _fail("missing recognizable car detail: " + piece_name)
            return
    for piece in details.get_children():
        if piece is CollisionObject3D or piece is CollisionShape3D:
            _fail("decorative car mesh contains a gameplay collider")
            return
    var visual: MeshInstance3D = car.get_node("Visual") as MeshInstance3D
    if not (visual.mesh is BoxMesh) or (visual.mesh as BoxMesh).size.y >= 1.0:
        _fail("tall cuboid body was not reshaped into sedan proportions")
        return
    if not car.configure(road, PackedInt32Array([11]), Profile.new()):
        _fail("detailed car cannot be configured for a valid route")
        return
    var first_color: int = details.color_variant()
    var initial_position: Vector3 = car.global_position
    car.physics_obstacle_checks_enabled = false
    for step in range(15):
        car.advance_fixed(0.05)
    if car.global_position.distance_to(initial_position) <= 0.1:
        _fail("new vehicle visuals stopped the car from moving")
        return
    if not car.configure(road, PackedInt32Array([11]), Profile.new()):
        _fail("vehicle cannot resume deterministic configuration")
        return
    if details.color_variant() != first_color:
        _fail("same lane selected a nondeterministic paint color")
        return
    if not car.configure(road, PackedInt32Array([12]), Profile.new()):
        _fail("vehicle cannot reconfigure to another legal lane")
        return
    if details.color_variant() == first_color:
        _fail("different lanes have no visual paint variety")
        return
    car.queue_free()
    print("CIVIC_CHAOS_VEHICLE_VISUALS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
