class_name CivicNPCRoutineWorldAdapter
extends RefCounted
## GAME-025-A3 gated draft. Reads real walkers and physical-clearance checks,
## then returns *advice* to the existing movement controller. No animation,
## position, crossing reservation, score or checkpoint mutations happen here.
const Routines = preload("res://scripts/npc/npc_daily_routines.gd")
const Intent = preload("res://scripts/npc/npc_routine_intent.gd")
const Stops = preload("res://scripts/npc/npc_routine_waypoints.gd")

var _clock: CivicNPCRoutines
var _enabled: bool = false

func configure(agent_count: int, seed_value: int = Routines.DEFAULT_SEED) -> bool:
    if _clock != null:
        return false
    var next_clock := Routines.new() as CivicNPCRoutines
    if not next_clock.configure(agent_count, seed_value):
        return false
    _clock = next_clock
    return true

func advance_to_simulation_tick(tick: int) -> bool:
    # Future live integration must pass FourWayJunction.simulation.clock.tick_index
    # and never independently derive a tick from render delta or OS time.
    return _clock != null and _clock.advance_to(tick)

func inspect_walker(pedestrians: Node3D, index: int) -> Dictionary:
    if _clock == null or pedestrians == null or not is_instance_valid(pedestrians):
        return {}
    if not pedestrians.is_inside_tree() or index < 0 or index >= _clock.agent_count():
        return {}
    if not pedestrians.has_method("_walk_position") or not pedestrians.has_method("_recovery_position_is_clear") or not pedestrians.has_method("_walker_in_crossing_conflict"):
        return {}
    var walkers: Array = pedestrians.get("_walkers")
    var progress_values: Array = pedestrians.get("_walker_progress")
    var crossing_values: Array = pedestrians.get("_crossing")
    if index >= walkers.size() or index >= progress_values.size() or index >= crossing_values.size():
        return {}
    var walker_data: Dictionary = walkers[index]
    var root: Node3D = walker_data.get("root") as Node3D
    var side: int = int(walker_data.get("side", -1))
    if root == null or not is_instance_valid(root) or side < 0 or side > 3:
        return {}
    var half_length: float = float(pedestrians.get("district_extent")) * 1.65 * 0.5
    var route_length: float = half_length * 2.0
    var travel_progress: float = fposmod(float(progress_values[index]), route_length) - half_length
    var agenda: Dictionary = _clock.agent_state(index)
    if agenda.is_empty():
        return {}
    var destination: String = str(agenda["destination"])
    var target_progress: float = Stops.target_progress(destination, float(pedestrians.get("district_extent")), side)
    if not is_finite(target_progress):
        return {}
    var occupied_crossing: bool = bool(pedestrians.call("_walker_in_crossing_conflict", index, side))
    var reserved_crossing: bool = bool(crossing_values[index])
    var reached: bool = Stops.is_near_stop(travel_progress, target_progress)
    var on_lane: bool = false
    var point_clear: bool = false
    if reached and not occupied_crossing and not reserved_crossing:
        var sidewalk: Vector3 = pedestrians.call("_walk_position", side, travel_progress)
        var lateral: Vector3 = root.position - sidewalk
        lateral.y = 0.0
        on_lane = lateral.length_squared() <= 0.75 * 0.75
        if on_lane and Stops.is_safe_progress(travel_progress, half_length):
            # Existing walker physical validation checks player/other NPCs,
            # vehicles and buildings. The adapter never invents a shortcut.
            point_clear = bool(pedestrians.call("_recovery_position_is_clear", index, root.position))
    var suggestion: Dictionary = Intent.decide(
        index, _clock.current_tick(), int(_clock.checkpoint_state()["seed"]),
        occupied_crossing, reserved_crossing, false, reached and on_lane and point_clear
    )
    if suggestion.is_empty():
        return {}
    suggestion["target_progress"] = target_progress
    suggestion["at_safe_stop"] = reached and on_lane and point_clear
    suggestion["pause_for_activity"] = suggestion["mode"] == "perform_activity"
    return suggestion

func checkpoint_state() -> Dictionary:
    return _clock.checkpoint_state() if _clock != null else {}

func checkpoint_valid(data: Variant) -> bool:
    return _clock != null and _clock.checkpoint_valid(data)

func restore_checkpoint(data: Variant) -> bool:
    return _clock != null and _clock.restore_checkpoint(data)
