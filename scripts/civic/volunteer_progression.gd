class_name CivicVolunteerProgression
extends RefCounted
## PROG-01: read-only long-term goals derived from verified civic receipts.
## Never grants scores, rewrites missions, or trusts unaudited client counters.
const GOALS: Array[int] = [3, 10, 25, 50]
const BADGES: Array[String] = [
    "First Responder", "Neighborhood Helper", "Market Guardian", "Civic Champion"
]

static func rank_for(reputation: int) -> String:
    if reputation >= 700:
        return "Community Champion"
    if reputation >= 600:
        return "Trusted Volunteer"
    if reputation >= 540:
        return "Neighborhood Helper"
    return "New Volunteer"

static func overview(reputation: int, resolved: int, processed: Dictionary) -> Dictionary:
    if reputation < 0 or reputation > 1000 or resolved < 0:
        return {}
    var count: int = 0
    for raw_id in processed.keys():
        var id: String = str(raw_id)
        if not id.begins_with("free_roam:") or not id.ends_with(":resolved"):
            continue
        if processed[raw_id] != true:
            return {}
        count += 1
    # The accepted Free Roam checkpoint enforces this same count. Display
    # cannot be elevated using only a fabricated UI counter.
    if count != resolved:
        return {}
    var badges: Array[String] = []
    var next_goal: int = 0
    var next_title: String = ""
    for index in range(GOALS.size()):
        if count >= GOALS[index]:
            badges.append(BADGES[index])
        elif next_goal == 0:
            next_goal = GOALS[index]
            next_title = BADGES[index]
    return {
        "rank": rank_for(reputation),
        "activities": count,
        "badges": badges,
        "next_goal": next_goal,
        "next_title": next_title,
        "remaining": maxi(0, next_goal - count)
    }
