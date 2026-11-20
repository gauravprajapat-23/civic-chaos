extends SceneTree
## VEH-003: repeated full-envelope car contact, denied forward intrusion,
## and permitted only decreasing-overlap reverse recovery.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_forward", "move_back", "move_left", "move_right",
            "look_left", "look_right", "look_up", "look_down", "jump",
            "sprint", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.collision_layer = 1
    floor.position.y = -0.3
    var support := CollisionShape3D.new()
    var slab := BoxShape3D.new()
    slab.size = Vector3(40, 0.6, 40)
    support.shape = slab
    floor.add_child(support)
    stage.add_child(floor)
    var player := PlayerScene.instantiate() as CivicPlayerController
    player.position = Vector3(1.2, 0.15, 0)
    stage.add_child(player)
    var bike := Bike.new() as CivicRideableBike
    bike.position.y = 0.15
    stage.add_child(bike)
    await physics_frame
    if not player.mount_bike(bike):
        _fail("bike mount failed on clear road")
        return
    player.set_physics_process(false)
    player._bike_heading = 0.0
    var start: Vector3 = player.global_position
    var car := StaticBody3D.new()
    car.name = "CarImpactFixture"
    car.collision_layer = 4
    car.position = start + Vector3(0, 0, -2.0)
    var car_collision := CollisionShape3D.new()
    var car_box := BoxShape3D.new()
    car_box.size = Vector3(1.6, 1.6, 1.0)
    car_collision.shape = car_box
    car_collision.position.y = 0.8
    car.add_child(car_collision)
    stage.add_child(car)
    await physics_frame
    # Simulate repeated full-speed throttle at a parked car. The bike
    # must remain on the safe side; nothing teleports or pushes the car.
    for tick in range(40):
        player._bike_speed = 12.0
        player.velocity = Vector3(0, 0, -12)
        player._limit_bike_motion(0.1)
        if player.velocity.z < -0.5 or player._bike_speed > 0.5:
            _fail("impact allowed an excessive forward step at tick %d" % tick)
            return
        if player.global_position.distance_to(start) > 0.001:
            _fail("collision limiter teleported player")
            return
        if car.global_position.distance_to(start + Vector3(0, 0, -2)) > 0.001:
            _fail("static car moved under impact")
            return
    var interaction := bike.get_node("InteractionShape") as CollisionShape3D
    var prior: Transform3D = interaction.transform
    bike.update_ride_visuals(0.0, 0.0, 0.05, 0.0)
    if absf(bike._visual_rig.rotation.x) > 0.08 or interaction.transform != prior:
        _fail("impact moved the physics collider or exceeded visual pitch bound")
        return
    for frame in range(35):
        bike.update_ride_visuals(0.0, 0.0, 0.05, 0.0)
    if absf(bike._visual_rig.rotation.x) > 0.005:
        _fail("impact compression failed to settle")
        return
    # A shallow pre-existing overlap is permitted to retreat only if
    # penetration decreases and no *new* obstacle is touched.
    car.position.z = start.z - 1.67
    await physics_frame
    if bike.footprint_clear_at(start, 0.0, [player.get_rid()]):
        _fail("reverse fixture did not overlap front footprint")
        return
    for tick in range(2):
        player._bike_speed = 2.0
        player.velocity = Vector3(0, 0, -2.0)
        player._limit_bike_motion(0.05)
        if player.velocity.z < -0.001:
            _fail("front overlap permitted advancing into car")
            return
        player._bike_speed = -2.0
        player.velocity = Vector3(0, 0, 2.0)
        player._limit_bike_motion(0.05)
        if player.velocity.z < 0.5:
            _fail("safe reverse was blocked at tick %d" % tick)
            return
        player.global_position += Vector3(0, 0, 0.10)
        await physics_frame
    player.set_physics_process(false)
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_RIDE_07_IMPACT_STRESS_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
