class_name CivicSocialInfluence
extends RefCounted
## Deterministic, bounded influence from nearby observed civic behavior.

const POSITIVE_EVENTS := ["waited_for_green", "helped_person", "used_crosswalk"]
const NEGATIVE_EVENTS := ["ignored_signal", "blocked_sidewalk", "littered"]

static func calculate(events: Array, attentiveness: float) -> float:
    if not is_finite(attentiveness):
        return 0.0
    var weight := clampf(attentiveness, 0.0, 1.0)
    var total := 0.0
    for event in events:
        if not event is Dictionary:
            continue
        var kind: String = str(event.get("kind", ""))
        var proximity: float = float(event.get("proximity", 0.0))
        if not is_finite(proximity):
            continue
        var contribution := clampf(proximity, 0.0, 1.0) * weight * 0.25
        if POSITIVE_EVENTS.has(kind):
            total += contribution
        elif NEGATIVE_EVENTS.has(kind):
            total -= contribution
    return clampf(total, -1.0, 1.0)

static func apply_to_observations(observations: Dictionary, events: Array, attentiveness: float) -> Dictionary:
    var updated := observations.duplicate(true)
    updated["social_influence"] = calculate(events, attentiveness)
    return updated
