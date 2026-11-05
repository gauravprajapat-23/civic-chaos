class_name CivicTrafficSignalController
extends RefCounted
## Fixed-step two-axis traffic lights with amber and all-red clearance.

signal phase_changed(phase_name: String)

enum Phase { NS_GREEN, NS_AMBER, ALL_RED_NS, EW_GREEN, EW_AMBER, ALL_RED_EW }

var green_seconds: float = 12.0
var amber_seconds: float = 3.0
var clearance_seconds: float = 2.0
var phase: Phase = Phase.NS_GREEN
var phase_elapsed: float = 0.0

func _init(green: float = 12.0, amber: float = 3.0, clearance: float = 2.0) -> void:
    green_seconds = green
    amber_seconds = amber
    clearance_seconds = clearance
    reset()

func is_valid() -> bool:
    return is_finite(green_seconds) and green_seconds > 0.0 and is_finite(amber_seconds) and amber_seconds > 0.0 and is_finite(clearance_seconds) and clearance_seconds > 0.0

func reset() -> void:
    phase = Phase.NS_GREEN
    phase_elapsed = 0.0

func advance_fixed(delta: float) -> void:
    if not is_valid() or not is_finite(delta) or delta <= 0.0:
        return
    var remaining := delta
    while remaining > 0.000001:
        var duration := _phase_duration()
        var available := maxf(0.0, duration - phase_elapsed)
        var step := minf(remaining, available)
        phase_elapsed += step
        remaining -= step
        if phase_elapsed >= duration - 0.000001:
            phase = (int(phase) + 1) % 6
            phase_elapsed = 0.0
            phase_changed.emit(phase_name())

func phase_name() -> String:
    return ["NS_GREEN", "NS_AMBER", "ALL_RED_NS", "EW_GREEN", "EW_AMBER", "ALL_RED_EW"][int(phase)]

func aspect_for_approach(approach: String) -> String:
    var north_south := approach == "N" or approach == "S"
    var east_west := approach == "E" or approach == "W"
    if not north_south and not east_west:
        return "red"
    if north_south:
        if phase == Phase.NS_GREEN:
            return "green"
        if phase == Phase.NS_AMBER:
            return "amber"
    if east_west:
        if phase == Phase.EW_GREEN:
            return "green"
        if phase == Phase.EW_AMBER:
            return "amber"
    return "red"

func has_conflicting_green() -> bool:
    return aspect_for_approach("N") == "green" and aspect_for_approach("E") == "green"

func _phase_duration() -> float:
    if phase == Phase.NS_GREEN or phase == Phase.EW_GREEN:
        return green_seconds
    if phase == Phase.NS_AMBER or phase == Phase.EW_AMBER:
        return amber_seconds
    return clearance_seconds
