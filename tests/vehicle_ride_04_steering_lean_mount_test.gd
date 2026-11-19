extends SceneTree
## VEHICLE-RIDE-04: A and D must produce opposite, physically correct
## turns for a -Z-forward motorcycle. Cosmetic lean, steering fork
## and suspension must never rotate physics or parked interaction bodies.
const Bike = preload("res://scripts/world/rideable_bike.gd")
const Player = preload("res://scripts/player/player_controller.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var right_yaw: float = Player.bike_steering_delta(1.0, 8.0, 0.1)
    var left_yaw: float = Player.bike_steering_delta(-1.0, 8.0, 0.1)
    var reverse_right: float = Player.bike_steering_delta(1.0, -3.0, 0.1)
    var reverse_left: float = Player.bike_steering_delta(-1.0, -3.0, 0.1)
    if right_yaw >= -0.001 or left_yaw <= 0.001 or (
            absf(right_yaw + left_yaw) > 0.001):
        _fail("D must steer toward +X/right and A toward -X/left while moving forward")
        return
    if reverse_right <= 0.001 or reverse_left >= -0.001:
        _fail("reverse steering must invert A and D correctly")
        return
    if Player.bike_steering_delta(1.0, 0.0, 0.1) != 0.0 or (
            Player.bike_steering_delta(0.0, 8.0, 0.1) != 0.0):
        _fail("bike turned with no motion or no steering input")
        return
    var forward_right: Vector3 = Vector3(-sin(right_yaw), 0, -cos(right_yaw))
    var forward_left: Vector3 = Vector3(-sin(left_yaw), 0, -cos(left_yaw))
    if forward_right.x <= 0.0 or forward_left.x >= 0.0:
        _fail("Godot -Z heading and A/D steering mapped to wrong world sides")
        return

    var bike := Bike.new() as CivicRideableBike
    root.add_child(bike)
    var fork := bike.find_child("SteeringFork", true, false) as Node3D
    var rig := bike.find_child("VisualRig", true, false) as Node3D
    var interaction := bike.get_node("InteractionShape") as CollisionShape3D
    var front := bike.find_child("FrontWheel", true, false) as MeshInstance3D
    var handlebar := bike.find_child("Handlebar", true, false) as MeshInstance3D
    if fork == null or rig == null or interaction == null or front == null or handlebar == null:
        _fail("articulated bike has missing fork, wheel, collider or visual rig")
        return
    if front.get_parent() != fork or handlebar.get_parent() != fork:
        _fail("steering fork doesn't drive front wheel and handlebars together")
        return
    var original_shape: Transform3D = interaction.transform
    var original_bike: Transform3D = bike.transform
    for step in range(12):
        bike.animate_wheels(0.25)
        bike.update_ride_visuals(1.0, 9.0, 0.05, 0.25)
    if fork.rotation.y >= -0.05 or bike.get_visual_lean() >= -0.03:
        _fail("D doesn't turn the fork or lean the motorcycle right")
        return
    if interaction.transform != original_shape or bike.transform != original_bike:
        _fail("art-only lean illegally tilted player/world collision shapes")
        return
    for step in range(18):
        bike.animate_wheels(0.25)
        bike.update_ride_visuals(-1.0, 9.0, 0.05, 0.25)
    if fork.rotation.y <= 0.05 or bike.get_visual_lean() <= 0.02:
        _fail("A doesn't turn the fork or lean the motorcycle left")
        return
    for step in range(18):
        bike.update_ride_visuals(0.0, 0.0, 0.05, 0.0)
    if absf(bike.get_visual_lean()) > 0.01 or absf(fork.rotation.y) > 0.01:
        _fail("bike didn't settle upright and align fork after stopping")
        return
    for step in range(12):
        bike.update_ride_visuals(1.0, -6.0, 0.05, -0.20)
    if bike.get_visual_lean() <= 0.02:
        _fail("reverse leaning doesn't follow the reversed turn")
        return
    bike.reset_ride_visuals()
    if absf(bike.get_visual_lean()) > 0.0001 or absf(fork.rotation.y) > 0.0001 or (
            rig.position != Vector3.ZERO):
        _fail("parked bike visual pose was not restored")
        return
    bike.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_04_STEERING_LEAN_MOUNT_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
