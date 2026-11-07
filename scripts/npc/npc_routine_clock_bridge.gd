class_name CivicNPCRoutineClockBridge
extends RefCounted
## GAME-025-A3 draft: explicit, opt-in link from the authoritative fixed-step
## SimulationDirector to the preview-only pedestrian routine model.
## Never drives a separate clock. Main gameplay does not create this bridge.

var _director: SimulationDirector
var _pedestrians: Node3D
var _last_tick: int = -1
var _attached: bool = false

func attach(director: SimulationDirector, pedestrians: Node3D) -> bool:
    if _attached or director == null or pedestrians == null:
        return false
    if not is_instance_valid(director) or not is_instance_valid(pedestrians):
        return false
    if director.clock == null or not pedestrians.is_inside_tree():
        return false
    if not pedestrians.has_method("daily_routine_preview_enabled") or not pedestrians.has_method("advance_daily_routine_tick"):
        return false
    if not bool(pedestrians.call("daily_routine_preview_enabled")):
        return false
    var current_tick: int = director.clock.tick_index
    if current_tick < 0 or not bool(pedestrians.call("advance_daily_routine_tick", current_tick)):
        return false
    _director = director
    _pedestrians = pedestrians
    _last_tick = current_tick
    _attached = true
    var callback: Callable = Callable(self, "_on_simulation_tick")
    if not director.simulation_tick.is_connected(callback):
        director.simulation_tick.connect(callback)
    return true

func detach() -> void:
    if _attached and is_instance_valid(_director):
        var callback: Callable = Callable(self, "_on_simulation_tick")
        if _director.simulation_tick.is_connected(callback):
            _director.simulation_tick.disconnect(callback)
    _attached = false
    _director = null
    _pedestrians = null
    _last_tick = -1

func _on_simulation_tick(at_tick: int, _delta: float) -> void:
    if not _attached or not is_instance_valid(_director) or not is_instance_valid(_pedestrians):
        detach()
        return
    if _director.clock == null:
        detach()
        return
    if at_tick != _director.clock.tick_index or at_tick < _last_tick:
        # Never advance to an inconsistent or stale timeline.
        detach()
        return
    if not bool(_pedestrians.call("advance_daily_routine_tick", at_tick)):
        detach()
        return
    _last_tick = at_tick

func attached() -> bool:
    return _attached and is_instance_valid(_director) and is_instance_valid(_pedestrians)

func last_tick() -> int:
    return _last_tick
