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
    var first: AnimatableBody3D = walkers.get_child(0) as AnimatableBody3D
    var second: AnimatableBody3D = walkers.get_child(1) as AnimatableBody3D
    var original_second: Vector3 = second.position
    second.position = first.position + Vector3(0.65, 0, 0)
    if not walkers._walker_path_occupied(0, first.position, first.position + Vector3(0.15, 0, 0)):
        push_error("pedestrian path clearance failed")
        quit(1)
        return
    second.position = original_second
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
