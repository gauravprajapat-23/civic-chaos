extends SceneTree
## VEHICLE-RIDE-05C: visual geometry and original collision guarantees.
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var bike := Bike.new() as CivicRideableBike
    root.add_child(bike)
    var required := [
        "FrameSpine_-1", "FrameSpine_1", "RearSwingarm_-1",
        "RearSwingarm_1", "FrontForkStanchion_-1",
        "FrontForkStanchion_1", "FrontForkLower_-1",
        "FrontForkLower_1", "HandlebarCrossbar",
        "HandlebarGrip_-1", "HandlebarGrip_1",
        "BrakeLever_-1", "BrakeLever_1",
        "EngineCylinder", "EngineFin_0",
        "EngineFin_4", "ExhaustCan_-1", "ExhaustCan_1"
    ]
    for name in required:
        var node := bike.find_child(name, true, false)
        if not (node is MeshInstance3D) or not node.visible:
            _fail("missing visible motorcycle geometry: " + name)
            return
    var fork := bike.find_child("SteeringFork", true, false) as Node3D
    if fork == null:
        _fail("steering fork missing")
        return
    for name in ["FrontForkStanchion_-1", "FrontForkStanchion_1",
            "HandlebarCrossbar", "HandlebarGrip_-1", "HandlebarGrip_1",
            "BrakeLever_-1", "BrakeLever_1"]:
        var part := bike.find_child(name, true, false) as Node3D
        if part.get_parent() != fork:
            _fail("steering geometry disconnected from fork: " + name)
            return
    for name in ["Fork", "Handlebar", "Chassis", "EngineBlock"]:
        var old := bike.find_child(name, true, false) as MeshInstance3D
        if old == null or old.visible:
            _fail("old box placeholder still visible: " + name)
            return
    var interaction := bike.get_node("InteractionShape") as CollisionShape3D
    if interaction.shape == null or bike.collision_layer != 16:
        _fail("motorcycle collision/interaction changed")
        return
    var original: Transform3D = interaction.transform
    for frame in range(12):
        bike.update_ride_visuals(1.0, 8.0, 0.05, 0.2)
    if fork.rotation.y >= -0.05 or interaction.transform != original:
        _fail("steering did not move geometry safely")
        return
    bike.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05C_GEOMETRY_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
