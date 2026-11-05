class_name CivicDeadlockDetector
extends RefCounted
## Wait-for graph cycle detector. Signals and unowned obstacles are not edges.
var waits: Dictionary = {}
var current_tick: int = -1
var minimum_wait_ticks: int = 20

func observe(vehicle_id: int, blocker_id: int, tick: int, reason: String = "vehicle") -> bool:
    if vehicle_id < 0 or tick < current_tick or reason != "vehicle":
        return false
    if blocker_id < 0 or blocker_id == vehicle_id:
        return false
    current_tick = tick
    var old: Dictionary = waits.get(vehicle_id, {})
    var started: int = int(old.get("since", tick)) if int(old.get("blocker", -1)) == blocker_id else tick
    waits[vehicle_id] = {"blocker": blocker_id, "since": started}
    return true

func clear_wait(vehicle_id: int) -> void:
    waits.erase(vehicle_id)

func advance_to(tick: int) -> bool:
    if tick < current_tick:
        return false
    current_tick = tick
    return true

func detect_cycles() -> Array[PackedInt32Array]:
    var cycles: Array[PackedInt32Array] = []
    var seen: Dictionary = {}
    var ids: Array = waits.keys()
    ids.sort()
    for start in ids:
        if seen.has(start):
            continue
        var path: Array[int] = []
        var positions: Dictionary = {}
        var node: int = int(start)
        while waits.has(node) and not seen.has(node):
            if positions.has(node):
                var cycle := PackedInt32Array()
                for index in range(int(positions[node]), path.size()):
                    cycle.append(path[index])
                if cycle.size() >= 2 and _cycle_is_stable(cycle):
                    cycle.sort()
                    cycles.append(cycle)
                break
            positions[node] = path.size()
            path.append(node)
            node = int(waits[node]["blocker"])
        for visited in path:
            seen[visited] = true
    return cycles

func _cycle_is_stable(cycle: PackedInt32Array) -> bool:
    for id in cycle:
        if current_tick - int(waits[id]["since"]) < minimum_wait_ticks:
            return false
    return true

func snapshot() -> Dictionary:
    return {"tick": current_tick, "waits": waits.duplicate(true), "cycles": detect_cycles()}
