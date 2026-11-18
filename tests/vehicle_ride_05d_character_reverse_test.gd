extends SceneTree
## Regression: the mounted rider must look like the actual playable
## character, rather than substituting a different simplified person.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Bike = preload("res://scripts/world/rideable_bike.gd")
const Player = preload("res://scripts/player/player_controller.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_forward", "move_back", "move_left", "move_right",
            "look_left", "look_right", "look_up", "look_down",
            "jump", "sprint", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var road := StaticBody3D.new()
    road.name = "Ground"
    road.collision_layer = 1
    road.position.y = -0.3
    var road_collision := CollisionShape3D.new()
    road_collision.name = "CollisionShape3D"
    var road_shape := BoxShape3D.new()
    road_shape.size = Vector3(80.0, 0.6, 80.0)
    road_collision.shape = road_shape
    road.add_child(road_collision)
    stage.add_child(road)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0.0)
    stage.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    bike.position.y = 0.15
    stage.add_child(bike)
    await physics_frame
    var original_face := player.visual.get_node("Head/Face") as MeshInstance3D
    var original_shirt := player.visual.get_node("Torso/Shirt") as MeshInstance3D
    if not player.mount_bike(bike):
        _fail("player could not mount clear bike")
        return
    var rig := bike.find_child("MountedRiderRig", true, false) as CivicMotorcycleRiderRig
    if rig == null:
        _fail("mounted rider rig missing")
        return
    var face := rig.get_node_or_null("RiderHead/Face") as MeshInstance3D
    var hair := rig.get_node_or_null("RiderHead/HairCap") as MeshInstance3D
    var nose := rig.get_node_or_null("RiderHead/Nose") as MeshInstance3D
    var shirt := rig.get_node_or_null("RiderTorso/Shirt") as MeshInstance3D
    if face == null or hair == null or nose == null or shirt == null:
        _fail("mounted rider changed original face/hair/clothes")
        return
    if face.mesh.get_class() != original_face.mesh.get_class() or (
            (face.material_override as StandardMaterial3D).albedo_color !=
            (original_face.material_override as StandardMaterial3D).albedo_color):
        _fail("rider face material/mesh no longer matches main player")
        return
    if shirt.mesh.get_class() != original_shirt.mesh.get_class() or (
            (shirt.material_override as StandardMaterial3D).albedo_color !=
            (original_shirt.material_override as StandardMaterial3D).albedo_color):
        _fail("rider clothing no longer matches main player")
        return
    if player.visual.visible:
        _fail("second walking model remains visible while riding")
        return
    if Player.bike_throttle_input(0.8, 0.0, true) > -0.99:
        _fail("physical S did not override lingering forward input")
        return
    if Player.bike_throttle_input(0.0, 1.0, false) > -0.99:
        _fail("Android downward joystick did not request reverse")
        return
    if Player.bike_throttle_input(1.0, 0.0, false) < 0.99:
        _fail("forward input is broken")
        return
    player.set_physics_process(false)
    player._bike_exit_cooldown = 0.0
    player._bike_speed = 0.0
    player.velocity = Vector3.ZERO
    await physics_frame
    if not player.dismount_bike():
        _fail("unobstructed rider could not dismount")
        return
    if not player.visual.visible or bike.rider != null:
        _fail("original main character was not restored on dismount")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_05D_CHARACTER_REVERSE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
