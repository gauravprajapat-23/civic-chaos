extends SceneTree
## Spawn separation and recovery when previously overlapped pedestrians are found.
## NPCs are sensors for traffic, not hard collision bodies against each other.
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")
const MIN_SPACING: float = 0.72

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := CharacterBody3D.new()
    player.name = "PlayerRoot"
    player.position = Vector3(5.7, 0.25, -8.0)
    player.collision_layer = 2
    player.collision_mask = 1
    stage.add_child(player)
    var walkers := Walkers.new()
    walkers.pedestrian_count = 12
    stage.add_child(walkers)
    await physics_frame
    if walkers._walkers.size() != walkers.pedestrian_count:
        _fail("crowd capacity unexpectedly lost a pedestrian")
        return
    for walker in walkers.get_children():
        if not walker is AnimatableBody3D:
            _fail("pedestrian is not traffic-detectable AnimatableBody3D")
            return
        if walker.collision_layer != 8 or walker.collision_mask != 0:
            _fail("NPC must be a sensing-only body without NPC/player hard collision")
            return
    if not _clear_spacing(walkers, player, 1.0, 1.2):
        _fail("spawned pedestrian overlaps another actor")
        return
    for tick in range(240):
        await physics_frame
        if not _clear_spacing(walkers, player, MIN_SPACING, 0.72):
            _fail("NPC-to-actor overlap during normal simulation at frame %d" % tick)
            return
    # Simulate a previously corrupted save or legacy frame with two walkers
    # in exactly the same place: recovery must separate locally.
    walkers.set_physics_process(false)
    var a: Node3D = walkers._walkers[0]["root"]
    var b: Node3D = walkers._walkers[1]["root"]
    a.position = Vector3(15.0, 0.23, 15.0)
    b.position = Vector3(15.0, 0.23, 15.0)
    await physics_frame
    walkers.set_physics_process(true)
    for tick in range(45):
        await physics_frame
    var difference: Vector3 = a.position - b.position
    difference.y = 0.0
    if difference.length() < MIN_SPACING:
        _fail("overlapped NPCs failed to recover personal space")
        return
    # Explicitly reproduce the screenshot: player and NPC share one position.
    # No hard character collision is allowed to trap them together.
    walkers.set_physics_process(false)
    player.global_position = a.global_position
    await physics_frame
    walkers.set_physics_process(true)
    for tick in range(45):
        await physics_frame
    var player_gap: Vector3 = a.global_position - player.global_position
    player_gap.y = 0.0
    if player_gap.length() < 1.0:
        _fail("NPC remained embedded inside the player after overlap recovery")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_PEDESTRIAN_SPAWN_SEPARATION_PASS")
    quit(0)

func _clear_spacing(walkers: Node3D, player: Node3D, npc_min: float, player_min: float) -> bool:
    var children: Array = walkers.get_children()
    for i in range(children.size()):
        var separation: Vector3 = children[i].global_position - player.global_position
        separation.y = 0.0
        if separation.length() < player_min:
            return false
        for j in range(i + 1, children.size()):
            var between: Vector3 = children[i].global_position - children[j].global_position
            between.y = 0.0
            if between.length() < npc_min:
                return false
    return true

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
