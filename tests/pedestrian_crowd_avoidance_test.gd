extends SceneTree
## Reproduce close pedestrian approaches, opposing walkers and route recovery.
## Real physics-frame assertions: no root-space overlap and no permanent stalls.
const Walkers = preload("res://scripts/npc/district_pedestrians.gd")
const GAP: float = 0.72

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var walkers := Walkers.new()
    walkers.pedestrian_count = 4
    stage.add_child(walkers)
    await physics_frame
    var loop_length: float = walkers.district_extent * 1.65

    # Two perpendicular sidewalk routes enter the same coordinate (5, 5).
    _position_walker(walkers, 0, 0, 3.5, 1.0, loop_length)
    _position_walker(walkers, 2, 2, 3.5, 1.0, loop_length)
    await physics_frame
    if not _is_separated(walkers):
        _fail("initial crossing arrangement overlaps")
        return
    for tick in range(420):
        await physics_frame
        if not _is_separated(walkers):
            _fail("crossing pedestrians intersected at frame %d" % tick)
            return
    if walkers._walker_progress[0] < loop_length * 0.5 + 5.7 or walkers._walker_progress[2] < loop_length * 0.5 + 5.7:
        _fail("perpendicular walkers stalled instead of yielding/passing")
        return

    # Two head-on pedestrians on one artificial corridor; negative speed is
    # used only in this regression to force actual opposing movement.
    _position_walker(walkers, 0, 0, -1.3, 1.0, loop_length)
    _position_walker(walkers, 1, 0, 1.3, -1.0, loop_length)
    _position_walker(walkers, 2, 2, -10.0, 1.0, loop_length)
    _position_walker(walkers, 3, 3, -10.0, 1.0, loop_length)
    await physics_frame
    if not _is_separated(walkers):
        _fail("initial head-on arrangement overlaps")
        return
    for tick in range(420):
        await physics_frame
        if not _is_separated(walkers):
            _fail("head-on pedestrians intersected at frame %d" % tick)
            return
    if walkers._walker_progress[0] <= loop_length * 0.5 + 0.8:
        _fail("forward head-on walker failed to make progress")
        return
    if walkers._walker_progress[1] >= loop_length * 0.5 - 0.8:
        _fail("opposing head-on walker failed to make progress")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_PEDESTRIAN_CROWD_AVOIDANCE_PASS")
    quit(0)

func _position_walker(walkers: Node3D, index: int, side: int, progress: float, speed: float, loop_length: float) -> void:
    var entry: Dictionary = walkers._walkers[index]
    entry["side"] = side
    entry["speed"] = speed
    var root_body: AnimatableBody3D = entry["root"] as AnimatableBody3D
    root_body.position = walkers._walk_position(side, progress)
    walkers._walker_progress[index] = loop_length * 0.5 + progress
    walkers._sidestep_offsets[index] = 0.0
    walkers._blocked_frames[index] = 0

func _is_separated(walkers: Node3D) -> bool:
    var list: Array = walkers.get_children()
    for i in range(list.size()):
        for j in range(i + 1, list.size()):
            var separation: Vector3 = list[i].position - list[j].position
            separation.y = 0.0
            if separation.length_squared() < GAP * GAP - 0.00001:
                return false
    return true

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
