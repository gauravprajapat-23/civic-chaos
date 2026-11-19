extends SceneTree
## VEHICLE-RIDE-05B: rig follows handlebar steering and bike lean.
const Bike = preload("res://scripts/world/rideable_bike.gd")
const RiderRig = preload("res://scripts/world/motorcycle_rider_rig.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var player := Node3D.new()
    player.name = "RiderAnchor"
    root.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    root.add_child(bike)
    if not bike.mount_to(player):
        _fail("could not mount test bike")
        return
    var rig := bike.find_child("MountedRiderRig", true, false) as CivicMotorcycleRiderRig
    var fork := bike.find_child("SteeringFork", true, false) as Node3D
    if rig == null or fork == null or rig.get_parent().name != "VisualRig":
        _fail("mounted rider is not owned by bike visual rig")
        return
    for side in ["Left", "Right"]:
        if fork.get_node_or_null(side + "GripTarget") == null or (
                rig.get_node_or_null(side + "FootpegTarget") == null):
            _fail("grip or footpeg targets missing: " + side)
            return
    for steer in [-1.0, 0.0, 1.0]:
        for step in range(12):
            bike.update_ride_visuals(steer, 9.0, 0.05, 0.25)
        for side in ["Left", "Right"]:
            var hand := rig.get_node(side + "Hand") as MeshInstance3D
            var target := fork.get_node(side + "GripTarget") as Marker3D
            var boot := rig.get_node(side + "Boot") as MeshInstance3D
            var peg := rig.get_node(side + "FootpegTarget") as Marker3D
            if hand.global_position.distance_to(target.global_position) > 0.002:
                _fail("hand detached from turning grip: " + side)
                return
            if boot.global_position.distance_to(peg.global_position) > 0.002:
                _fail("boot detached from footpeg: " + side)
                return
        if not (rig.get_node("SeatedHips") as Node3D).position.is_equal_approx(
                Vector3(0, 1.30, 0.43)):
            _fail("rider hips moved away from saddle")
            return
    if not bike.park() or bike.find_child("MountedRiderRig", true, false) == null:
        # queue_free occurs at the next frame, so the rig may remain briefly.
        if bike.rider != null:
            _fail("bike ownership not released on park")
            return
    await process_frame
    if bike.find_child("MountedRiderRig", true, false) != null:
        _fail("parked bike still owns an active rider mesh")
        return
    print("CIVIC_CHAOS_VEHICLE_RIDE_05B_RIDER_RIG_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
