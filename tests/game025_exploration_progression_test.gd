extends SceneTree
## GAME-025-04: persistence and recognition must be idempotent, and
## tampered checkpoints/reward counters cannot grant repeated points.
const Exploration = preload("res://scripts/world/living_city_exploration.gd")
const Zones = preload("res://scripts/world/living_city_zones.gd")
const Progression = preload("res://scripts/civic/volunteer_progression.gd")
const Repository = preload("res://scripts/core/save_repository.gd")
const PATH: String = "user://game025_exploration_progression_test.json"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var player := Node3D.new()
    stage.add_child(player)
    var area := Exploration.new() as CivicLivingCityExploration
    stage.add_child(area)
    if not area.configure(player):
        _fail("could not configure exploration")
        return
    var signals: Array[String] = []
    area.zone_discovered.connect(func(id: String, _title: String) -> void:
        signals.append(id)
    )
    for zone in Zones.all():
        area.scan_position(zone["position"])
        area.scan_position(zone["position"])
    if signals.size() != 4 or int(area.visit_state()["count"]) != 4:
        _fail("repeat visits generated duplicate discoveries")
        return
    var checkpoint: Dictionary = area.checkpoint_state()
    if not Exploration.checkpoint_valid(checkpoint):
        _fail("valid exploration checkpoint was rejected")
        return
    var corrupted: Dictionary = checkpoint.duplicate(true)
    corrupted["visited_ids"].append("unlisted_zone")
    if Exploration.checkpoint_valid(corrupted):
        _fail("unlisted discovery accepted")
        return
    corrupted = checkpoint.duplicate(true)
    corrupted["visited_ids"][0] = corrupted["visited_ids"][1]
    if Exploration.checkpoint_valid(corrupted):
        _fail("duplicate discovery accepted")
        return
    corrupted = checkpoint.duplicate(true)
    corrupted["schema_version"] = 3
    if Exploration.checkpoint_valid(corrupted):
        _fail("unsupported checkpoint schema accepted")
        return

    if not Repository.write_save({"player": {"x": 0.0, "y": 0.0, "z": 0.0, "yaw": 0.0},
            "exploration_checkpoint": checkpoint}, PATH):
        _fail("checksum-protected exploration save failed")
        return
    var saved: Dictionary = Repository.read_save(PATH)
    if saved.is_empty() or not Exploration.checkpoint_valid(saved.get("exploration_checkpoint")):
        _fail("saved exploration did not survive JSON round trip")
        return
    var restored := Exploration.new() as CivicLivingCityExploration
    stage.add_child(restored)
    if not restored.configure(player) or not restored.restore_checkpoint(saved["exploration_checkpoint"]):
        _fail("saved exploration was not restored")
        return
    if int(restored.visit_state()["count"]) != 4:
        _fail("visits disappeared after restore")
        return
    var repeat_notices: Array[String] = []
    restored.zone_discovered.connect(func(id: String, _title: String) -> void:
        repeat_notices.append(id)
    )
    for zone in Zones.all():
        restored.scan_position(zone["position"])
    if not repeat_notices.is_empty():
        _fail("restored visits emitted discovery twice")
        return
    if not Progression.exploration_goal(4, 3, {
        "free_roam:1:resolved": true,
        "free_roam:2:resolved": true,
        "free_roam:3:resolved": true
    }).get("earned", false):
        _fail("valid civic receipts did not unlock earned explorer recognition")
        return
    if bool(Progression.exploration_goal(4, 3, {}).get("earned", false)):
        _fail("fabricated activity count unlocked explorer recognition")
        return
    if bool(Progression.exploration_goal(4, 2, {
        "free_roam:1:resolved": true, "free_roam:2:resolved": true
    }).get("earned", false)):
        _fail("unmet civic activity minimum unlocked recognition")
        return
    if bool(Progression.exploration_goal(3, 3, {
        "free_roam:1:resolved": true,
        "free_roam:2:resolved": true,
        "free_roam:3:resolved": true
    }).get("earned", false)):
        _fail("unvisited landmark unlocked recognition")
        return
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
    stage.queue_free()
    print("CIVIC_CHAOS_GAME025_EXPLORATION_PROGRESSION_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
