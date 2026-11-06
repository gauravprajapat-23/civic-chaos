extends SceneTree
## Test that occupied city entry points are rejected before the vehicle is active.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Spawner = preload("res://scripts/traffic/traffic_spawner.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var spawner := Spawner.new()
    stage.add_child(spawner)
    if not spawner.configure(Builder.make_city_graph(), 1234, true):
        _fail("expanded-city graph rejected")
        return
    var blockers: Array[StaticBody3D] = []
    for lane_id in spawner.city_entry_lanes:
        var entry: Vector3 = spawner.road_graph.get_lane(lane_id).centerline[0]
        var blocker := StaticBody3D.new()
        blocker.collision_layer = 2 # Player / street-user footprint.
        blocker.collision_mask = 0
        blocker.global_position = entry
        var collision := CollisionShape3D.new()
        var capsule := CapsuleShape3D.new()
        capsule.radius = 0.4
        capsule.height = 1.8
        collision.shape = capsule
        collision.position.y = 0.9
        blocker.add_child(collision)
        stage.add_child(blocker)
        blockers.append(blocker)
    await physics_frame
    if spawner.try_spawn() or not spawner.active_vehicles.is_empty():
        _fail("car spawned into an occupied city entrance")
        return
    for blocker in blockers:
        blocker.queue_free()
    await physics_frame
    await physics_frame
    if not spawner.try_spawn():
        _fail("car did not spawn after actors vacated entry points")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_VEHICLE_SPAWN_OCCUPANCY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
