extends SceneTree
## GAME-016 — an owner never drives through a real service-route obstruction.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Parking = preload("res://scripts/civic/illegal_parking_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.name = "TerrainGround"
    ground.collision_layer = 1
    ground.position.y = -0.25
    var ground_shape := CollisionShape3D.new()
    ground_shape.name = "CollisionShape3D"
    var slab := BoxShape3D.new()
    slab.size = Vector3(140, 0.5, 100)
    ground_shape.shape = slab
    ground.add_child(ground_shape)
    stage.add_child(ground)
    var player := Node3D.new()
    player.position = Parking.OWNER_START + Vector3(0, 0, 1.8)
    stage.add_child(player)
    var civic := Session.new()
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic session failed")
        return
    var parking := Parking.new()
    stage.add_child(parking)
    if not parking.configure(stage, player, civic):
        _fail("physical parking scene not configured")
        return
    var obstacle := StaticBody3D.new()
    obstacle.name = "UnauthorizedObstacle"
    obstacle.collision_layer = 1
    obstacle.collision_mask = 0
    obstacle.position = Vector3(24, 0.8, -7.5)
    var wall_collider := CollisionShape3D.new()
    wall_collider.name = "CollisionShape3D"
    var wall_shape := BoxShape3D.new()
    wall_shape.size = Vector3(2.0, 1.6, 1.2)
    wall_collider.shape = wall_shape
    obstacle.add_child(wall_collider)
    stage.add_child(obstacle)
    for frame in range(370):
        await physics_frame
        if parking.observed_blockage:
            break
    if not parking.observed_blockage or not parking.perform_incident_action(player, "inspect") or not parking.perform_incident_action(player, "request_owner"):
        _fail("could not begin authorized relocation after a real blockage")
        return
    for frame in range(370):
        await physics_frame
    var trapped_position: Vector3 = parking.parked_vehicle.position
    if parking.relocation_complete or parking.finished:
        _fail("vehicle escaped through an actual obstacle")
        return
    if trapped_position.z < -5.9:
        _fail("moving parked car penetrated route obstruction")
        return
    if civic.metrics.processed_events.has("parking:%d:reopened" % parking.incident_id):
        _fail("blocked relocation incorrectly awarded reputation")
        return
    obstacle.queue_free()
    await physics_frame
    await physics_frame
    var progressed: bool = false
    for frame in range(300):
        await physics_frame
        if parking.parked_vehicle.position.z < trapped_position.z - 0.7:
            progressed = true
            break
    if not progressed:
        _fail("owner did not resume after actual obstacle was removed")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_ILLEGAL_PARKING_OBSTACLE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
