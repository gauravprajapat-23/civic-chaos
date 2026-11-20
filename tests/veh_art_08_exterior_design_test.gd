extends SceneTree
## VEH-ART-08: new visible detail must not mutate collision envelopes,
## vehicle routes, steering assembly or LOD draw budget.
const VehicleScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Bike = preload("res://scripts/world/rideable_bike.gd")
var failures: int = 0

func _assert(valid: bool, why: String) -> void:
    if not valid:
        failures += 1
        push_error("VEH-ART-08: " + why)

func _collision_count(node: Node) -> int:
    var count: int = 1 if node is CollisionShape3D else 0
    for part in node.get_children():
        count += _collision_count(part)
    return count

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var car: CivicVehicleAgent = VehicleScene.instantiate() as CivicVehicleAgent
    root.add_child(car)
    await process_frame
    var appearance: CivicVehicleVisuals = car.get_node_or_null("DetailVisuals") as CivicVehicleVisuals
    _assert(appearance != null, "car visual rig missing")
    if appearance != null:
        var identity: Node3D = appearance.get_node_or_null("BodyDesign08") as Node3D
        _assert(identity != null, "car exterior details not built")
        if identity != null:
            for part_name in ["FrontPlate", "RearPlate", "FrontLowerIntake",
                    "FogLamp_L", "FogLamp_R", "SideRocker_L",
                    "SideRocker_R", "RearMudflap_L", "RearMudflap_R",
                    "RoofAntenna"]:
                _assert(identity.get_node_or_null(part_name) is MeshInstance3D,
                    "car detailing missing " + part_name)
            _assert(_collision_count(identity) == 0,
                "new car trim added a physics collider")
            appearance.set_lane_variant(102)
            var prior_identity: Dictionary = appearance.visual_identity()
            appearance.set_detail_level(CivicVehicleVisuals.DETAIL_NEAR)
            _assert(identity.visible and
                (identity.get_node("FogLamp_L") as MeshInstance3D).visible,
                "close-up detail hidden")
            appearance.set_detail_level(CivicVehicleVisuals.DETAIL_MID)
            _assert(identity.visible and
                not (identity.get_node("FogLamp_L") as MeshInstance3D).visible and
                (identity.get_node("FrontPlate") as MeshInstance3D).visible,
                "middle LOD retained too much decoration")
            appearance.set_detail_level(CivicVehicleVisuals.DETAIL_FAR)
            _assert(not identity.visible,
                "far LOD did not cull all newly added trim")
            appearance.set_detail_level(CivicVehicleVisuals.DETAIL_NEAR)
            _assert(appearance.visual_identity() == prior_identity,
                "LOD changed deterministic paint/driver identity")
        _assert(car.get_node_or_null("Visual") != null and
            car.get_node_or_null("Cabin") != null,
            "new trim broke legacy car silhouette nodes")

    var bike: CivicRideableBike = Bike.new() as CivicRideableBike
    root.add_child(bike)
    await process_frame
    var visual: Node3D = bike.get_node_or_null("VisualRig") as Node3D
    _assert(visual != null and visual.has_node("SteeringFork"),
        "motorcycle steering assembly disappeared")
    if visual != null:
        for part_name in ["RearTailCowl08", "RearPlate08",
                "ChainGuard08", "SideTankInset08_L",
                "SideTankInset08_R", "PassengerPeg08_L", "PassengerPeg08_R"]:
            _assert(visual.get_node_or_null(part_name) is MeshInstance3D,
                "motorcycle exterior missing " + part_name)
        for part_name in ["RearTailCowl08", "RearPlate08",
                "ChainGuard08", "SideTankInset08_L", "SideTankInset08_R"]:
            var part: MeshInstance3D = visual.get_node_or_null(part_name) as MeshInstance3D
            if part != null:
                _assert(part.position.x >= -0.6 and part.position.x <= 0.6 and
                    part.position.z >= -1.55 and part.position.z <= 1.55,
                    "new motorcycle part extends outside original footprint")
        _assert(_collision_count(visual) == 0,
            "new motorcycle design altered the physics envelope")
    bike.queue_free()
    car.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_VEH_ART_08_EXTERIOR_PASS")
    else:
        print("CIVIC_CHAOS_VEH_ART_08_EXTERIOR_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
