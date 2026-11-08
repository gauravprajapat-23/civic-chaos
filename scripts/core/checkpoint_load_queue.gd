class_name CivicCheckpointLoadQueue
extends RefCounted
## One outstanding F9/recovery load, bound to the document selected at input.
## The consumer must run on the next physics tick before staging actors.
## Never reread a save after consuming: an F5 between request and restore
## must not mix generations or silently select a different campaign state.

var _pending: bool = false
var _snapshot: Dictionary = {}

func request(document: Dictionary) -> bool:
    if _pending:
        return false
    _snapshot = document.duplicate(true)
    _pending = true
    return true

func has_pending() -> bool:
    return _pending

func consume() -> Dictionary:
    if not _pending:
        return {}
    _pending = false
    var chosen: Dictionary = _snapshot
    _snapshot = {}
    return chosen

func clear() -> void:
    _pending = false
    _snapshot = {}
