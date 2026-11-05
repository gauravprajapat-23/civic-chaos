class_name CivicNpcPersonality
extends Resource
## Normalized NPC traits, each in [0, 1].

@export_range(0.0, 1.0, 0.01) var patience: float = 0.5
@export_range(0.0, 1.0, 0.01) var rule_compliance: float = 0.5
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.5
@export_range(0.0, 1.0, 0.01) var empathy: float = 0.5
@export_range(0.0, 1.0, 0.01) var attentiveness: float = 0.5

func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    for trait in ["patience", "rule_compliance", "aggression", "empathy", "attentiveness"]:
        var value: float = get(trait)
        if not is_finite(value) or value < 0.0 or value > 1.0:
            errors.append("%s_out_of_bounds" % trait)
    return errors

func to_data() -> Dictionary:
    return {"patience": patience, "rule_compliance": rule_compliance, "aggression": aggression, "empathy": empathy, "attentiveness": attentiveness}

static func from_data(data: Dictionary) -> CivicNpcPersonality:
    var personality := CivicNpcPersonality.new()
    for trait in ["patience", "rule_compliance", "aggression", "empathy", "attentiveness"]:
        if data.has(trait):
            personality.set(trait, float(data[trait]))
    return personality

static func seeded(seed: int) -> Resource:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    var personality := CivicNpcPersonality.new()
    personality.patience = rng.randf()
    personality.rule_compliance = rng.randf()
    personality.aggression = rng.randf()
    personality.empathy = rng.randf()
    personality.attentiveness = rng.randf()
    return personality
