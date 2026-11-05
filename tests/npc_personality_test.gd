extends SceneTree

const Personality = preload("res://scripts/npc/npc_personality.gd")
const Blackboard = preload("res://scripts/npc/npc_blackboard.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var first: CivicNpcPersonality = Personality.seeded(12345) as CivicNpcPersonality
    var second: CivicNpcPersonality = Personality.seeded(12345) as CivicNpcPersonality
    if not first.validate().is_empty() or first.to_data() != second.to_data():
        _fail("seeded personality invalid or nondeterministic")
        return
    var restored: CivicNpcPersonality = Personality.from_data(first.to_data()) as CivicNpcPersonality
    if restored.to_data() != first.to_data():
        _fail("personality serialization mismatch")
        return
    restored.aggression = 1.5
    if restored.validate().is_empty():
        _fail("out of range trait accepted")
        return
    var board := Blackboard.new()
    var observation := {"nearby": [{"id": 7, "distance": 3.0}], "signal": "red"}
    if not board.update_snapshot(5, 12, observation):
        _fail("valid snapshot rejected")
        return
    observation["signal"] = "green"
    if board.snapshot()["observations"]["signal"] != "red":
        _fail("snapshot retained mutable input")
        return
    var copy := board.snapshot()
    copy["observations"]["signal"] = "amber"
    if board.snapshot()["observations"]["signal"] != "red":
        _fail("snapshot exposed mutable state")
        return
    if board.update_snapshot(5, 11, {}) or board.update_snapshot(6, 13, {}):
        _fail("stale or foreign observation accepted")
        return
    var loaded := Blackboard.from_json(board.to_json())
    if loaded == null or loaded.to_json() != board.to_json():
        _fail("blackboard JSON roundtrip failed")
        return
    if board.update_snapshot(5, 13, {"bad": INF}):
        _fail("nonfinite observation accepted")
        return
    print("CIVIC_CHAOS_NPC_PERSONALITY_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
