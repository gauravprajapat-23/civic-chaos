extends SceneTree
## GAME-023: ignored events expire without points or unbounded incidents.
const FreeRoam = preload("res://scripts/civic/free_roam_events.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic manager could not initialize")
        return
    var roam := FreeRoam.new() as CivicFreeRoamEvents
    stage.add_child(roam)
    if not roam.configure(player, civic):
        _fail("Free Roam did not configure")
        return
    for frame in range(20):
        roam._physics_process(0.25)
    if roam.active_event.is_empty():
        _fail("no event spawned to test expiry")
        return
    var id: int = int(roam.active_event["incident_id"])
    var current_metrics: Dictionary = civic.metrics.scores.duplicate(true)
    var duration: int = int(roam.director.definitions[roam.active_event["kind"]]["duration"])
    for frame in range(duration * 4):
        roam._physics_process(0.25)
        if roam.expired_total > 0:
            break
    if roam.expired_total != 1 or not roam.active_event.is_empty():
        _fail("ignored event did not expire exactly once")
        return
    if not roam.director.active.is_empty() or roam.director.budget != 1:
        _fail("expired event or immediate respawn exhausted the scheduler budget")
        return
    if civic.incidents.incidents[id]["state"] != CivicIncidentManager.RESOLVED:
        _fail("expired incident was not closed in the history")
        return
    if civic.metrics.scores != current_metrics or civic.metrics.processed_events.has("free_roam:%d:resolved" % id):
        _fail("expired incident fabricated a player reward")
        return
    for frame in range(16):
        roam._physics_process(0.25)
    if not roam.active_event.is_empty():
        _fail("next incident bypassed the explicit cooldown")
        return
    if not FreeRoam.checkpoint_valid(roam.checkpoint_state(), civic.snapshot()):
        _fail("expired event state cannot be safely resumed")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_FREE_ROAM_EXPIRY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
