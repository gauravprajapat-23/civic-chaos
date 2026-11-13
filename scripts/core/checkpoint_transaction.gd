class_name CivicCheckpointTransaction
extends RefCounted
## GAME-018: freezes mission simulation while a multi-actor checkpoint is
## applied/rolled back. Retains each node's prior physics-processing state.
## This guards the in-scene transaction, not background traffic globally.

var _suspended: Array[Dictionary] = []
var _active: bool = false

func begin(nodes: Array) -> bool:
    if _active:
        return false
    _active = true
    var seen: Dictionary = {}
    for actor in nodes:
        if not (actor is Node) or not is_instance_valid(actor):
            continue
        var node: Node = actor as Node
        var id: int = node.get_instance_id()
        if seen.has(id):
            continue
        seen[id] = true
        _suspended.append({
            "node": node,
            "was_running": node.is_physics_processing()
        })
        node.set_physics_process(false)
    return true

func finish() -> void:
    if not _active:
        return
    # Restore the previous configuration; a node deliberately disabled
    # before the save must not be activated as a side effect of loading.
    for record in _suspended:
        var node: Node = record["node"]
        if is_instance_valid(node) and not node.is_queued_for_deletion():
            node.set_physics_process(bool(record["was_running"]))
    _suspended.clear()
    _active = false

func is_active() -> bool:
    return _active
