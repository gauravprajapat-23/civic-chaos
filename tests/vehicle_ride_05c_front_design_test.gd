extends SceneTree
## VEHICLE-RIDE-05C-FRONT: all front details steer together while
## leaving the verified footprint and rider hand targets unchanged.
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var bike := Bike.new() as CivicRideableBike
    root.add_child(bike)
    var fork := bike.find_child("SteeringFork", true, false) as Node3D
    if fork == null:
        _fail("missing steering fork")
        return
    var expected := [
        "HeadlampBucket", "HeadlampBezel", "HeadlampLens",
        "FrontCowl", "FrontIndicator_-1", "FrontIndicator_1",
        "IndicatorStalk_-1", "IndicatorStalk_1",
        "FrontFenderBridge", "Speedometer", "FrontBrakeHose",
        "ForkDustSeal_-1", "ForkDustSeal_1",
        "AxleEnd_-1", "AxleEnd_1"
    ]
    for name in expected:
        var detail := bike.find_child(name, true, false) as MeshInstance3D
        if detail == null or detail.get_parent() != fork or not detail.visible:
            _fail("front detail missing or not attached to fork: " + name)
            return
    for name in ["Headlight", "FrontNumberPlate", "FrontMudguard"]:
        var legacy := bike.find_child(name, true, false) as MeshInstance3D
        if legacy == null or legacy.visible:
            _fail("legacy front rectangle remains visible: " + name)
            return
    var left := bike.find_child("FrontIndicator_-1", true, false) as Node3D
    var right := bike.find_child("FrontIndicator_1", true, false) as Node3D
    if absf(left.position.x + right.position.x) > 0.001 or (
            left.position.y != right.position.y):
        _fail("front indicators are not symmetrical")
        return
    for side in [-1, 1]:
        for index in range(1, 9):
            var name := "FrontFenderRib_%d_%d" % [side, index]
            var rib := bike.find_child(name, true, false) as MeshInstance3D
            if rib == null or rib.get_parent() != fork:
                _fail("curved fender section missing: " + name)
                return
    var interaction := bike.get_node("InteractionShape") as CollisionShape3D
    var original: Transform3D = interaction.transform
    for i in range(14):
        bike.update_ride_visuals(1.0, 8.0, 0.05, 0.2)
    if fork.rotation.y >= -0.05 or interaction.transform != original:
        _fail("front details did not steer or visual steering moved collider")
        return
    if Bike.FOOTPRINT_SIZE != Vector3(1.15, 1.55, 3.05):
        _fail("redesign changed full motorcycle clearance dimensions")
        return
    var anchor := Node3D.new()
    root.add_child(anchor)
    if not bike.mount_to(anchor):
        _fail("mount failed after front redesign")
        return
    var rig := bike.find_child("MountedRiderRig", true, false) as CivicMotorcycleRiderRig
    if rig == null:
        _fail("rider rig not created")
        return
    for direction in [-1.0, 1.0]:
        for i in range(12):
            bike.update_ride_visuals(direction, 8.0, 0.05, 0.2)
        for side in ["Left", "Right"]:
            var hand := rig.get_node(side + "Hand") as Node3D
            var grip := fork.get_node(side + "GripTarget") as Marker3D
            if hand.global_position.distance_to(grip.global_position) > 0.002:
                _fail("hand no longer follows redesigned steering: " + side)
                return
    bike.queue_free()
    anchor.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05C_FRONT_DESIGN_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
