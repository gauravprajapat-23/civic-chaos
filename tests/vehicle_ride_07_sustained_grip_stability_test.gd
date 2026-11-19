extends SceneTree
## VEH-003: long sustained steering alternation with visual lean, pitch,
## wheel motion and repeated mount cleanup. Hand meshes must stay at
## their fork-owned grips under every accepted visual turn.
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var anchor := Node3D.new()
    root.add_child(anchor)
    var bike := Bike.new() as CivicRideableBike
    root.add_child(bike)
    if not bike.mount_to(anchor):
        _fail("visual bike mount failed")
        return
    var rig := bike.find_child("MountedRiderRig", true, false) as CivicMotorcycleRiderRig
    var fork := bike.find_child("SteeringFork", true, false) as Node3D
    if rig == null or fork == null:
        _fail("steering rig missing")
        return
    var pivot := bike.get_node("InteractionShape") as CollisionShape3D
    var original: Transform3D = pivot.transform
    for frame in range(480):
        var steer: float = sin(float(frame) * 0.055)
        var speed: float = -5.0 if frame % 100 >= 85 else 8.0
        bike.animate_wheels(speed * 0.016)
        if frame % 80 == 0:
            bike.register_impact(8.0)
        bike.update_ride_visuals(steer, speed, 0.016, speed * 0.016)
        for side in ["Left", "Right"]:
            var hand := rig.get_node(side + "Hand") as MeshInstance3D
            var grip := fork.get_node(side + "GripTarget") as Marker3D
            var boot := rig.get_node(side + "Boot") as MeshInstance3D
            var foot := rig.get_node(side + "FootpegTarget") as Marker3D
            if hand.global_position.distance_to(grip.global_position) > 0.003:
                _fail("hand detached from moving steering grip at frame %d: %s" % [frame, side])
                return
            if boot.global_position.distance_to(foot.global_position) > 0.003:
                _fail("boot detached from footpeg at frame %d: %s" % [frame, side])
                return
        if pivot.transform != original or absf(bike.get_visual_lean()) > bike.MAX_VISUAL_LEAN_RAD + 0.002:
            _fail("visual riding altered collision or exceeded lean bound")
            return
        if bike.get_child_count() == 0 or rig.get_parent().name != "VisualRig":
            _fail("rider changed owner during turn")
            return
    if not bike.park():
        _fail("park after sustained turn failed")
        return
    await process_frame
    if bike.find_child("MountedRiderRig", true, false) != null:
        _fail("stale rider duplicate remains after park")
        return
    for side in ["Left", "Right"]:
        if fork.get_node_or_null(side + "GripTarget") != null:
            _fail("stale fork grip remains after dismount")
            return
    if not bike.mount_to(anchor):
        _fail("remount after rig cleanup failed")
        return
    await process_frame
    if bike.find_children("MountedRiderRig", "Node3D", true, false).size() != 1:
        _fail("multiple rider rigs after remount")
        return
    root.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_07_GRIP_STABILITY_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
