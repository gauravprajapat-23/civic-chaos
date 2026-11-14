extends SceneTree
## CAR-SAFE-02: a real vehicle scene must yield to player/pedestrian bodies
## before contact and resume without tunnelling after clearance.
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Lane = preload("res://scripts/traffic/lane_data.gd")
const Graph = preload("res://scripts/traffic/road_graph.gd")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _person(layer: int, position: Vector3) -> StaticBody3D:
    var actor := StaticBody3D.new()
    actor.collision_layer = layer
    actor.collision_mask = 0
    actor.position = position
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    collider.shape = capsule
    collider.position.y = 0.9
    actor.add_child(collider)
    return actor

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var graph := Graph.new()
    var lane := Lane.new()
    lane.lane_id = 41
    lane.centerline = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -30)])
    if not graph.add_lane(lane):
        _fail("straight safety test lane missing")
        return
    var car: CivicVehicleAgent = CarScene.instantiate() as CivicVehicleAgent
    stage.add_child(car)
    if not car.configure(graph, PackedInt32Array([41]), Profile.new()):
        _fail("physical car could not follow the safety test lane")
        return
    var player := _person(2, Vector3(0, 0, -2.25))
    stage.add_child(player)
    await physics_frame
    if car.people_clear_at(car.global_transform):
        _fail("padded proximity check missed player in front of car")
        return
    var before := car.global_position
    for step in range(12):
        car.advance_fixed(0.05)
        await physics_frame
    if car.global_position.distance_to(before) > 0.001 or car.speed_mps > 0.001:
        _fail("vehicle drove into player despite human clearance")
        return
    player.global_position = Vector3(12, 0, 12)
    await physics_frame
    if not car.people_clear_at(car.global_transform):
        _fail("vehicle remained blocked after player left")
        return
    for step in range(16):
        car.advance_fixed(0.05)
        await physics_frame
    if car.global_position.z > -0.25:
        _fail("car never resumed after pedestrian space cleared")
        return
    var pedestrian := _person(8, car.global_position + Vector3(0, 0, -2.3))
    stage.add_child(pedestrian)
    await physics_frame
    if car.people_clear_at(car.global_transform):
        _fail("padded proximity check missed pedestrian in front of car")
        return
    var position_before := car.global_position
    for step in range(12):
        car.advance_fixed(0.05)
        await physics_frame
    if car.global_position.distance_to(position_before) > 0.001 or car.speed_mps > 0.001:
        _fail("vehicle intersected pedestrian after clearance stop")
        return
    pedestrian.global_position = Vector3(14, 0, 14)
    await physics_frame
    for step in range(16):
        car.advance_fixed(0.05)
        await physics_frame
    if car.global_position.z >= position_before.z - 0.20:
        _fail("vehicle failed to resume after pedestrian left")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_CAR_CHARACTER_CLEARANCE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
