class_name CivicVolunteerProgression
extends RefCounted
## PROG-01: read-only long-term goals derived from verified civic receipts.
## Never grants scores, rewrites missions, or trusts unaudited client counters.
const GOALS: Array[int] = [3, 10, 25, 50]
## Activity cycles, not real-world calendar dates: safe for offline saves,
## travel and device time changes. No separate rewards or streak penalties.
const ROTATION_SIZE: int = 4
const ROTATION_TITLES: Array[String] = [
    "Neighborhood Patrol", "Public Space Care", "Market Stewardship"
]

static func rotating_goal(resolved: int) -> Dictionary:
    if resolved < 0 or resolved > 1000000000:
        return {}
    var cycle: int = resolved / ROTATION_SIZE
    var progress: int = resolved % ROTATION_SIZE
    return {
        "cycle": cycle,
        "title": ROTATION_TITLES[cycle % ROTATION_TITLES.size()],
        "completed": progress,
        "target": ROTATION_SIZE,
        "remaining": ROTATION_SIZE - progress
    }
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
        "remaining": maxi(0, next_goal - count),
        "rotating_goal": rotating_goal(count)
    }
