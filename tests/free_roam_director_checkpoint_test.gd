extends SceneTree
## GAME-023: deterministic event scheduler survives JSON without RNG drift.
const Director = preload("res://scripts/civic/event_director.gd")

func _initialize() -> void:
    call_deferred("_run")

func _new() -> CivicEventDirector:
    var scheduler := Director.new() as CivicEventDirector
    if not scheduler.configure(11, 1, 1):
        return null
    for id in ["civic_litter", "fallen_public_sign"]:
        if not scheduler.register_event({"id": id, "cost": 1, "cooldown": 5,
                "duration": 90, "tags": ["public_space"], "conditions": {"reputation": 0}}):
            return null
    return scheduler

func _run() -> void:
    var a: CivicEventDirector = _new()
    var b: CivicEventDirector = _new()
    if a == null or b == null:
        _fail("seeded event scheduler could not configure")
        return
    var start: Dictionary = a.advance_to(10, {"reputation": 600})
    if not start.get("ok", false) or str(start.get("started", "")).is_empty():
        _fail("first event not scheduled")
        return
    var data: Variant = JSON.parse_string(JSON.stringify(a.checkpoint_state()))
    if not b.restore_checkpoint(data):
        _fail("valid JSON scheduler snapshot refused")
        return
    if b.checkpoint_state() != data:
        _fail("event instance, budget or 64-bit RNG changed on resume")
        return
    var forged: Dictionary = (data as Dictionary).duplicate(true)
    forged["rng_state"] = "not a number"
    if b.restore_checkpoint(forged):
        _fail("invalid RNG accepted")
        return
    forged = (data as Dictionary).duplicate(true)
    forged["active_instances"][0]["instance"] = 99
    if b.restore_checkpoint(forged):
        _fail("invented event instance accepted")
        return
    forged = (data as Dictionary).duplicate(true)
    forged["budget"] = -1
    if b.restore_checkpoint(forged):
        _fail("negative event budget accepted")
        return
    if b.checkpoint_state() != data:
        _fail("failed load changed live deterministic state")
        return
    var id: int = int(start["instance"])
    if not a.resolve_instance(id, 11) or not b.resolve_instance(id, 11):
        _fail("event resolution did not release scheduler budget")
        return
    if a.resolve_instance(id, 11) or b.resolve_instance(id, 11):
        _fail("event resolution granted budget twice")
        return
    if a.budget != 1 or b.budget != 1 or not a.active.is_empty() or a.snapshot() != b.snapshot():
        _fail("resolution failed deterministic replay")
        return
    for tick in range(12, 45):
        var aa: Dictionary = a.advance_to(tick, {"reputation": 600})
        var bb: Dictionary = b.advance_to(tick, {"reputation": 600})
        if aa != bb or a.snapshot() != b.snapshot():
            _fail("seeded scheduler diverged after resumed manual resolution")
            return
    print("CIVIC_CHAOS_FREE_ROAM_DIRECTOR_CHECKPOINT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
