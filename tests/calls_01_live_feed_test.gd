extends SceneTree
## CALLS-01: the dispatch feed uses actual Free Roam event identity
## and physical stage coordinates, never a synthetic UI call queue.
const Events = preload("res://scripts/civic/free_roam_events.gd")
const Challenges = preload("res://scripts/civic/free_roam_challenges.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var events := Events.new() as CivicFreeRoamEvents
    root.add_child(events)
    events.tick = 100
    events.next_spawn_tick = 120
    var idle: Dictionary = events.dispatch_state()
    if bool(idle["has_event"]) or int(idle["call_id"]) != -1 or (
            bool(idle["has_target"])):
        _fail("idle dispatch exposes a phantom incident")
        return

    events.active_event = {
        "kind": Challenges.SIGN, "instance": 9,
        "incident_id": 50009, "stage": 0, "site_id": "north_west",
        "tier": "priority", "deadline_tick": 165
    }
    var original: Dictionary = events.active_event.duplicate(true)
    var report: Dictionary = events.dispatch_state()
    var site: Dictionary = Challenges.site("north_west", Challenges.SIGN)
    if not bool(report["has_event"]) or int(report["call_id"]) != 50009 or (
            report["target"] != site["source"]) or (
            not bool(report["priority"])) or int(report["seconds_left"]) != 65:
        _fail("live dispatch did not expose actual ID, deadline or source location")
        return
    if events.active_event != original:
        _fail("reading calls mutated live incident progress")
        return

    events.active_event["stage"] = 2
    report = events.dispatch_state()
    if int(report["call_id"]) != 50009 or report["target"] != site["destination"]:
        _fail("carried incident did not route to the real destination")
        return
    events.active_event.clear()
    report = events.dispatch_state()
    if bool(report["has_event"]) or int(report["call_id"]) != -1 or (
            bool(report["has_target"])):
        _fail("completed call remains available for acceptance")
        return
    events.queue_free()
    print("CIVIC_CHAOS_CALLS_01_LIVE_FEED_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
