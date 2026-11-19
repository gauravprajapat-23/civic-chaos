extends SceneTree
## CAR-SAFE-04: checkpoint staging must reject a character within the
## protective buffer, preserve the old traffic generation on failure,
## and permit a valid restore once the road becomes safe.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")
const CarScene = preload("res://scenes/traffic/vehicle_agent.tscn")
const Profile = preload("res://scripts/traffic/vehicle_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _actor(layer: int, location: Vector3) -> StaticBody3D:
    var result := StaticBody3D.new()
    result.collision_layer = layer
    result.collision_mask = 0
    result.position = location
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    shape.shape = capsule
    shape.position.y = 0.9
    result.add_child(shape)
    return result

func _run() -> void:
    var graph: CivicRoadGraph = Builder.make_test_graph()
    var stage := Node3D.new()
    root.add_child(stage)
    var spawner: CivicTrafficSpawner = Spawner.new() as CivicTrafficSpawner
    stage.add_child(spawner)
    if not spawner.configure(graph, 4242):
        _fail("traffic graph configuration failed")
        return

    var entry: CivicLaneData = graph.get_lane(1)
    var outlet: CivicLaneData = graph.get_lane(4)
    if entry == null or outlet == null:
        _fail("test graph no longer has a 1-to-4 route")
        return
    var preview: CivicVehicleAgent = CarScene.instantiate() as CivicVehicleAgent
    stage.add_child(preview)
    if not preview.configure(graph, PackedInt32Array([1, 4]), Profile.new()):
        _fail("test route could not be configured")
        return
    preview.lane_distance_m = 2.0
    preview._place_on_lane()
    var center: Vector3 = preview.global_position
    var side: Vector3 = preview.global_transform.basis.x.normalized()
    preview.free()

    var checkpoint: Dictionary = spawner.snapshot()
    checkpoint["spawned_total"] = 1
    checkpoint["cars"] = [{
        "route": [1, 4], "route_index": 0,
        "lane_distance": 2.0, "speed": 0.0,
        "target_speed": 5.0, "stop_requested": false,
        "obstacle_checks": true, "delay": 0.0,
        "profile": {"max_speed": 8.0, "acceleration": 3.0,
            "braking": 6.0, "turn_rate": 2.5, "vehicle_mask": 1}
    }]
    if not spawner.can_restore(checkpoint):
        _fail("valid checkpoint was rejected before collision staging")
        return
    var original: Dictionary = spawner.snapshot()

    # This is outside the physical car body but inside its human buffer.
    var player := _actor(2, center + side * 1.42)
    stage.add_child(player)
    await physics_frame
    if spawner.prepare_restore(checkpoint):
        _fail("restored car overlapped the player's safety buffer")
        return
    if spawner.snapshot() != original or spawner.restore_prepared():
        _fail("rejected player collision changed traffic or left staged bodies")
        return

    player.position = center + Vector3(15, 0, 15)
    var walker := _actor(8, center + side * 1.42)
    stage.add_child(walker)
    await physics_frame
    if spawner.prepare_restore(checkpoint):
        _fail("restored car overlapped a pedestrian safety buffer")
        return
    if spawner.snapshot() != original or spawner.restore_prepared():
        _fail("rejected pedestrian collision changed traffic or left staged bodies")
        return

    walker.position = center + Vector3(17, 0, 17)
    await physics_frame
    if not spawner.prepare_restore(checkpoint):
        _fail("clear traffic checkpoint could not be staged after people moved")
        return
    if not spawner.restore_prepared():
        _fail("prepared checkpoint missing after a valid stage")
        return
    spawner.abort_restore()
    if spawner.restore_prepared() or spawner.snapshot() != original:
        _fail("aborting a valid staged checkpoint changed the live state")
        return
    if not spawner.prepare_restore(checkpoint) or not spawner.commit_restore():
        _fail("clear traffic checkpoint could not be committed")
        return
    if spawner.active_vehicles.size() != 1 or spawner.snapshot()["cars"].size() != 1:
        _fail("valid restoration lost its physical traffic vehicle")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_CAR_SAFE_04_CHECKPOINT_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
