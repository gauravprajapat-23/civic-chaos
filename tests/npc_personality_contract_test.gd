extends SceneTree
## AUD-001: isolate the previously reported NPC personality preload failure
## from the utility evaluator, script registration and crowd scene.
const PersonalityPath: String = "res://scripts/npc/npc_personality.gd"
const Personality = preload("res://scripts/npc/npc_personality.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var loaded: Script = load(PersonalityPath) as Script
    if loaded == null:
        _fail("NPC personality GDScript could not be loaded")
        return
    var direct: CivicNpcPersonality = Personality.new() as CivicNpcPersonality
    if direct == null or direct.get_script() != loaded:
        _fail("NPC personality preload constructed the wrong script resource")
        return
    if not direct.validate().is_empty():
        _fail("NPC personality factory defaults are invalid")
        return
    var seeded: CivicNpcPersonality = Personality.seeded(2025) as CivicNpcPersonality
    var replay: CivicNpcPersonality = Personality.seeded(2025) as CivicNpcPersonality
    if seeded == null or replay == null:
        _fail("seeded NPC personality factory failed to construct a resource")
        return
    if seeded.to_data() != replay.to_data() or not seeded.validate().is_empty():
        _fail("seeded personality was not deterministic or valid")
        return
    var copied: CivicNpcPersonality = Personality.from_data(seeded.to_data()) as CivicNpcPersonality
    if copied == null or copied.to_data() != seeded.to_data():
        _fail("NPC personality save-data factory failed exact state roundtrip")
        return
    if copied == seeded or copied == direct:
        _fail("personality factory reused another NPC's mutable resource")
        return
    copied.set("empathy", 0.0)
    if seeded.get("empathy") != replay.get("empathy"):
        _fail("modifying restored personality unexpectedly changed seeded source")
        return
    direct.set("rule_compliance", 2.0)
    if direct.validate().is_empty():
        _fail("invalid trait bounds no longer rejected")
        return
    print("CIVIC_CHAOS_NPC_PERSONALITY_CONTRACT_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
