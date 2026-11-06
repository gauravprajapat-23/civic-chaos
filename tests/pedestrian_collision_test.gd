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
    print("CIVIC_CHAOS_PEDESTRIAN_COLLISION_PASS")
    stage.queue_free()
    quit(0)
