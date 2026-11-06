extends SceneTree
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := CharacterBody3D.new()
    player.name = "PlayerRoot"
    player.position = Vector3(5, 0, 0)
    stage.add_child(player)
    var walkers := Walkers.new()
    stage.add_child(walkers)
    await physics_frame
    if walkers.get_child_count() != walkers.pedestrian_count:
        push_error("wrong pedestrian count")
        quit(1)
        return
    if not walkers._pedestrian_blocked(0, Vector3(5, 0.23, 0)):
        push_error("player avoidance failed")
        quit(1)
        return
    # Test the geometric clearance directly; physics-synchronized bodies can
    # defer manual position assignments until the next physics frame.
    if not Walkers._segment_near_point(Vector3.ZERO, Vector3(0.15, 0, 0), Vector3(0.65, 0, 0), 1.3):
        push_error("pedestrian path clearance failed")
        quit(1)
        return
    if Walkers._segment_near_point(Vector3.ZERO, Vector3(0.15, 0, 0), Vector3(3, 0, 0), 1.3):
        push_error("pedestrian path clearance falsely blocked distant NPC")
        quit(1)
        return
    for tick in range(120):
        await physics_frame
        for i in range(walkers.get_child_count()):
            var a: Node3D = walkers.get_child(i)
            for j in range(i + 1, walkers.get_child_count()):
                var other: Node3D = walkers.get_child(j)
                var separation: Vector3 = a.position - other.position
                separation.y = 0.0
                if separation.length_squared() < 0.64 * 0.64:
                    push_error("pedestrians overlap during simulation: %d %d" % [i, j])
                    quit(1)
                    return
    print("CIVIC_CHAOS_PEDESTRIAN_COLLISION_PASS")
    stage.queue_free()
    quit(0)
