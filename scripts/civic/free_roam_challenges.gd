class_name CivicFreeRoamChallenges
extends RefCounted
## GAME-024: deterministic, bounded Free Roam challenge and location catalog.
## Coordinates are outside carriageways, zebra crossings, buildings and fixed furniture.
const LITTER: String = "civic_litter"
const SIGN: String = "fallen_public_sign"
const CONE: String = "misplaced_safety_cone"
const PRIORITY_TICKS: int = 90
const ROUTINE_TICKS: int = 180

const SITES: Dictionary = {
    "north_east": {"label": "North market lane", "source": Vector3(9.0, 0.12, -29.0), "destination": Vector3(11.0, 0.12, -31.5)},
    "north_west": {"label": "North neighborhood verge", "source": Vector3(-9.0, 0.12, -27.0), "destination": Vector3(-11.0, 0.12, -29.5)},
    "south_east": {"label": "South market lane", "source": Vector3(9.0, 0.12, 29.0), "destination": Vector3(11.0, 0.12, 31.5)},
    "south_west": {"label": "South neighborhood verge", "source": Vector3(-9.0, 0.12, 27.0), "destination": Vector3(-11.0, 0.12, 29.5)},
    "east_north": {"label": "East market approach", "source": Vector3(28.0, 0.12, -9.0), "destination": Vector3(31.0, 0.12, -11.0)},
    "east_south": {"label": "East community street", "source": Vector3(28.0, 0.12, 9.0), "destination": Vector3(31.0, 0.12, 11.0)},
    "west_north": {"label": "West neighborhood street", "source": Vector3(-28.0, 0.12, -9.0), "destination": Vector3(-31.0, 0.12, -11.0)},
    "west_south": {"label": "West market approach", "source": Vector3(-28.0, 0.12, 9.0), "destination": Vector3(-31.0, 0.12, 11.0)}
}

static func all_kinds() -> Array[String]:
    return [LITTER, SIGN, CONE]

static func details(kind: String) -> Dictionary:
    match kind:
        LITTER:
            return {"title": "Discarded litter", "evidence": "A wrapper is damaging a shared public space.",
                "primary_kind": "litter", "receiver_kind": "bin",
                "primary_label": "LITTER  |  E / USE", "receiver_label": "RECYCLING BIN  |  E / USE",
                "collect": "collect_litter", "deposit": "deposit_litter",
                "collect_label": "Collect wrapper", "deposit_label": "Use recycling bin",
                "inspect_goal": "Inspect discarded litter", "collect_goal": "Collect the wrapper",
                "deposit_goal": "Place wrapper in green bin",
                "carry_target": "green recycling bin",
                "scores": {"cooperation": 2, "trust": 1}}
        SIGN:
            return {"title": "Fallen public sign", "evidence": "A fallen safety sign must be returned to its marked stand.",
                "primary_kind": "sign", "receiver_kind": "stand",
                "primary_label": "FALLEN SIGN  |  E / USE", "receiver_label": "SAFE SIGN STAND  |  E / USE",
                "collect": "collect_sign", "deposit": "place_sign",
                "collect_label": "Lift fallen sign", "deposit_label": "Place sign on safe stand",
                "inspect_goal": "Inspect the fallen sign", "collect_goal": "Lift the sign",
                "deposit_goal": "Return sign to safe stand",
                "carry_target": "blue sign stand",
                "scores": {"safety": 2, "efficiency": 1}}
        CONE:
            return {"title": "Misplaced safety cone", "evidence": "A misplaced cone creates an avoidable pedestrian obstruction.",
                "primary_kind": "cone", "receiver_kind": "rack",
                "primary_label": "LOOSE SAFETY CONE  |  E / USE", "receiver_label": "SAFETY STORAGE RACK  |  E / USE",
                "collect": "collect_cone", "deposit": "store_cone",
                "collect_label": "Pick up safety cone", "deposit_label": "Return cone to storage",
                "inspect_goal": "Inspect the safety cone", "collect_goal": "Collect the loose cone",
                "deposit_goal": "Return cone to storage rack",
                "carry_target": "safety storage rack",
                "scores": {"safety": 2, "cooperation": 1}}
    return {}

static func site_names() -> Array[String]:
    var names: Array[String] = []
    for site_id in SITES.keys():
        names.append(str(site_id))
    names.sort()
    return names

static func site_valid(site_id: String, kind: String) -> bool:
    return SITES.has(site_id) or site_id == "legacy_litter" and kind == LITTER or site_id == "legacy_sign" and kind == SIGN

static func site(site_id: String, kind: String = "") -> Dictionary:
    if SITES.has(site_id):
        return (SITES[site_id] as Dictionary).duplicate(true)
    if site_id == "legacy_litter" and kind == LITTER:
        return {"label": "Market Chowk walking area", "source": Vector3(18.5, 0.12, -26.0), "destination": Vector3(21.0, 0.10, -28.0)}
    if site_id == "legacy_sign" and kind == SIGN:
        return {"label": "Market Chowk walking area", "source": Vector3(-15.0, 0.12, -25.5), "destination": Vector3(-18.0, 0.12, -26.0)}
    return {}

static func choose_site(instance_id: int, previous_site: String, usable: Variant = null) -> String:
    var names: Array[String] = site_names()
    if names.is_empty() or instance_id <= 0:
        return ""
    # No global random state: a failed physics slot never consumes the event RNG.
    var offset: int = posmod(instance_id * 5 + 3, names.size())
    for step in range(names.size()):
        var candidate: String = names[(offset + step) % names.size()]
        if candidate == previous_site:
            continue
        if usable == null or usable is Callable and (usable as Callable).is_valid() and bool((usable as Callable).call(candidate)):
            return candidate
    # A busy district can legitimately defer an incident instead of clipping.
    return ""

static func tier(instance_id: int) -> String:
    return "priority" if instance_id % 3 == 0 else "routine"

static func deadline(instance_id: int, scheduled_end_tick: int) -> int:
    return scheduled_end_tick - (ROUTINE_TICKS - PRIORITY_TICKS) if tier(instance_id) == "priority" else scheduled_end_tick

static func reaction(kind: String, phase: String, instance_id: int) -> String:
    var subject: String = "that litter" if kind == LITTER else "the fallen sign" if kind == SIGN else "that loose cone"
    match phase:
        "spawned":
            return ["Someone should check %s." % subject, "That could cause trouble!", "The footpath needs attention."][posmod(instance_id, 3)]
        "inspected":
            return "Good catch! Can we make it safe?"
        "carried":
            return "Thanks for moving it carefully."
        "resolved":
            return "Nice work! Our street is safer."
        "expired":
            return "We missed a chance to help."
    return ""
