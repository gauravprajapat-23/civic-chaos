extends SceneTree
## GAME-018 — a restore transaction freezes only its actors and restores
## their exact pre-existing enabled/disabled physics state on every path.
const Guard = preload("res://scripts/core/checkpoint_transaction.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node.new()
    root.add_child(world)
    var live := Node.new()
    live.name = "MovingMission"
    world.add_child(live)
    live.set_physics_process(true)
    var inactive := Node.new()
    inactive.name = "CompletedMission"
    world.add_child(inactive)
    inactive.set_physics_process(false)
    var guard: CivicCheckpointTransaction = Guard.new()
    if not guard.begin([live, inactive, live, null]):
        _fail("transaction did not begin")
        return
    if live.is_physics_processing() or inactive.is_physics_processing():
        _fail("checkpoint application left physical actors moving")
        return
    if guard.begin([live]):
        _fail("concurrent checkpoint application was accepted")
        return
    guard.finish()
    if not live.is_physics_processing() or inactive.is_physics_processing() or guard.is_active():
        _fail("commit failed to restore the original physics scheduling")
        return
    # Rollback uses the exact same release operation.
    if not guard.begin([live, inactive]):
        _fail("transaction could not restart after commit")
        return
    guard.finish()
    if not live.is_physics_processing() or inactive.is_physics_processing():
        _fail("rollback incorrectly activated a completed incident")
        return
    # Queued node deletion must never result in restoring freed actors.
    if not guard.begin([live, inactive]):
        _fail("third transaction failed")
        return
    inactive.queue_free()
    guard.finish()
    if not live.is_physics_processing() or guard.is_active():
        _fail("transaction guard leaked a disabled live mission")
        return
    world.queue_free()
    print("CIVIC_CHAOS_CHECKPOINT_TRANSACTION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
