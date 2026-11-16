class_name CivicTrafficSignalController
extends RefCounted
## Fixed-step two-axis traffic lights with amber and all-red clearance.

signal phase_changed(phase_name: String)

enum Phase { NS_GREEN, NS_AMBER, ALL_RED_NS, EW_GREEN, EW_AMBER, ALL_RED_EW,
	N_GREEN, N_AMBER, ALL_RED_N, E_GREEN, E_AMBER, ALL_RED_E,
	S_GREEN, S_AMBER, ALL_RED_S, W_GREEN, W_AMBER, ALL_RED_W }

var green_seconds: float = 12.0
var amber_seconds: float = 3.0
var clearance_seconds: float = 2.0
var phase: Phase = Phase.NS_GREEN
var phase_elapsed: float = 0.0
var single_approach_mode: bool = false
const FOUR_WAY_FIRST: int = Phase.N_GREEN
const FOUR_WAY_PHASES: int = 12

func _init(green: float = 12.0, amber: float = 3.0, clearance: float = 2.0) -> void:
	green_seconds = green
	amber_seconds = amber
	clearance_seconds = clearance
	reset()

func is_valid() -> bool:
	return is_finite(green_seconds) and green_seconds > 0.0 and is_finite(amber_seconds) and amber_seconds > 0.0 and is_finite(clearance_seconds) and clearance_seconds > 0.0

func reset() -> void:
	phase = Phase.N_GREEN if single_approach_mode else Phase.NS_GREEN
	phase_elapsed = 0.0

func enable_single_approach_mode() -> void:
	single_approach_mode = true
	reset()
	phase_changed.emit(phase_name())

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
			phase = FOUR_WAY_FIRST + ((int(phase) - FOUR_WAY_FIRST + 1) % FOUR_WAY_PHASES) if single_approach_mode else (int(phase) + 1) % 6
			phase_elapsed = 0.0
			phase_changed.emit(phase_name())

## TRAFFIC-GAME-02 — constrained manual request, never an instant green.
## Only a green that has already served four seconds may be shortened.
## The normal phase machine still supplies amber and all-red; the next
## phase is always the opposite vehicle axis. No save-schema changes.
const MANUAL_MIN_GREEN_SECONDS: float = 4.0
const MANUAL_CHANGE_WAIT_SECONDS: float = 0.8

func request_next_green(axis: String) -> Dictionary:
	if single_approach_mode:
		if not is_valid() or not ["N", "E", "S", "W"].has(axis):
			return {"accepted": false, "reason": "invalid_axis"}
		if aspect_for_approach(axis) == "green":
			return {"accepted": false, "reason": "already_green"}
		if not [Phase.N_GREEN, Phase.E_GREEN, Phase.S_GREEN, Phase.W_GREEN].has(phase):
			return {"accepted": false, "reason": "clearance_in_progress"}
		if phase_elapsed < minf(MANUAL_MIN_GREEN_SECONDS, green_seconds):
			return {"accepted": false, "reason": "minimum_green"}
		if green_seconds - phase_elapsed <= MANUAL_CHANGE_WAIT_SECONDS:
			return {"accepted": false, "reason": "already_changing"}
		var next_index: int = (int((int(phase) - FOUR_WAY_FIRST) / 3.0) + 1) % 4
		if axis != ["N", "E", "S", "W"][next_index]:
			return {"accepted": false, "reason": "not_next_approach"}
		phase_elapsed = green_seconds - minf(MANUAL_CHANGE_WAIT_SECONDS, green_seconds * 0.5)
		return {"accepted": true, "reason": "amber_then_all_red", "target": axis}
	if not is_valid() or not ["NS", "EW"].has(axis):
		return {"accepted": false, "reason": "invalid_axis"}
	var target: Phase = Phase.NS_GREEN if axis == "NS" else Phase.EW_GREEN
	if phase == target:
		return {"accepted": false, "reason": "already_green"}
	var opposite: Phase = Phase.EW_GREEN if axis == "NS" else Phase.NS_GREEN
	if phase != opposite:
		return {"accepted": false, "reason": "clearance_in_progress"}
	if phase_elapsed < minf(MANUAL_MIN_GREEN_SECONDS, green_seconds):
		return {"accepted": false, "reason": "minimum_green"}
	var remaining: float = green_seconds - phase_elapsed
	if remaining <= MANUAL_CHANGE_WAIT_SECONDS:
		return {"accepted": false, "reason": "already_changing"}
	phase_elapsed = green_seconds - minf(MANUAL_CHANGE_WAIT_SECONDS, green_seconds * 0.5)
	return {"accepted": true, "reason": "amber_then_all_red", "target": axis}

func phase_name() -> String:
	var legacy: Array[String] = ["NS_GREEN", "NS_AMBER", "ALL_RED_NS", "EW_GREEN", "EW_AMBER", "ALL_RED_EW"]
	var directions: Array[String] = ["N_GREEN", "N_AMBER", "ALL_RED_N", "E_GREEN", "E_AMBER", "ALL_RED_E", "S_GREEN", "S_AMBER", "ALL_RED_S", "W_GREEN", "W_AMBER", "ALL_RED_W"]
	return directions[int(phase) - FOUR_WAY_FIRST] if single_approach_mode else legacy[int(phase)]

func aspect_for_approach(approach: String) -> String:
	if single_approach_mode:
		var direction_index: int = ["N", "E", "S", "W"].find(approach)
		if direction_index < 0:
			return "red"
		var local_phase: int = int(phase) - FOUR_WAY_FIRST
		if int(local_phase / 3.0) != direction_index:
			return "red"
		return "green" if local_phase % 3 == 0 else ("amber" if local_phase % 3 == 1 else "red")
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

## TRAFFIC-FIX-06: how long until this approach *next* receives green.
## Returns 0 when already green; read-only, exact same six-phase clock.
## Pedestrians use this to avoid starting a crossing that would persist
## into the conflicting vehicle axis's green.
func seconds_until_green(approach: String) -> float:
	if not is_valid() or not ["N", "S", "E", "W"].has(approach):
		return 0.0
	if aspect_for_approach(approach) == "green":
		return 0.0
	var remaining: float = _phase_duration() - phase_elapsed
	var total: int = FOUR_WAY_PHASES if single_approach_mode else 6
	var first: int = FOUR_WAY_FIRST if single_approach_mode else 0
	for shift in range(1, total + 1):
		var upcoming: int = first + ((int(phase) - first + shift) % total)
		var matched: bool = false
		if single_approach_mode:
			matched = upcoming == FOUR_WAY_FIRST + ["N", "E", "S", "W"].find(approach) * 3
		else:
			matched = (approach == "N" or approach == "S") and upcoming == Phase.NS_GREEN
			matched = matched or ((approach == "E" or approach == "W") and upcoming == Phase.EW_GREEN)
		if matched:
			return maxf(0.0, remaining)
		if (upcoming - first) % 3 == 0:
			remaining += green_seconds
		elif (upcoming - first) % 3 == 1:
			remaining += amber_seconds
		else:
			remaining += clearance_seconds
	return 0.0

func has_conflicting_green() -> bool:
	if not single_approach_mode:
		return aspect_for_approach("N") == "green" and aspect_for_approach("E") == "green"
	var green_count: int = 0
	for direction in ["N", "E", "S", "W"]:
		if aspect_for_approach(direction) == "green":
			green_count += 1
	return green_count > 1

func _phase_duration() -> float:
	if int(phase) % 3 == 0:
		return green_seconds
	if int(phase) % 3 == 1:
		return amber_seconds
	return clearance_seconds

## GAME-019: restore only legal phases and elapsed time within the phase.
## These exact timings preserve the amber/all-red safety schedule.
func snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"single_approach_mode": single_approach_mode,
		"phase": int(phase),
		"phase_elapsed": phase_elapsed,
		"green_seconds": green_seconds,
		"amber_seconds": amber_seconds,
		"clearance_seconds": clearance_seconds
	}

func can_restore(data: Variant) -> bool:
	if not (data is Dictionary) or not is_valid():
		return false
	if not (data.get("schema_version") is int or data.get("schema_version") is float):
		return false
	if float(data["schema_version"]) != 1.0:
		return false
	var saved_phase: Variant = data.get("phase")
	if not (saved_phase is int or saved_phase is float):
		return false
	var numeric_phase: float = float(saved_phase)
	if not is_finite(numeric_phase) or numeric_phase != floorf(numeric_phase) or numeric_phase < 0.0 or numeric_phase > (17.0 if single_approach_mode else 5.0):
		return false
	if data.has("single_approach_mode") and not (data["single_approach_mode"] is bool):
		return false
	if bool(data.get("single_approach_mode", false)) and not single_approach_mode:
		return false
	for field in ["green_seconds", "amber_seconds", "clearance_seconds"]:
		if not (data.get(field) is int or data.get(field) is float):
			return false
		if not is_finite(float(data[field])):
			return false
	if absf(float(data["green_seconds"]) - green_seconds) > 0.00001 or absf(float(data["amber_seconds"]) - amber_seconds) > 0.00001 or absf(float(data["clearance_seconds"]) - clearance_seconds) > 0.00001:
		return false
	var elapsed: Variant = data.get("phase_elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)):
		return false
	var duration: float = clearance_seconds
	if int(saved_phase) % 3 == 0:
		duration = green_seconds
	elif int(saved_phase) % 3 == 1:
		duration = amber_seconds
	return float(elapsed) >= 0.0 and float(elapsed) < duration

func restore(data: Variant) -> bool:
	if not can_restore(data):
		return false
	var restored: int = int(data["phase"])
	if single_approach_mode and restored < FOUR_WAY_FIRST:
		var base: int = Phase.N_GREEN if restored < 3 else Phase.E_GREEN
		restored = base + restored % 3
	phase = restored
	phase_elapsed = float(data["phase_elapsed"])
	# Refresh visuals/listeners after a restored phase. Never advance time.
	phase_changed.emit(phase_name())
	return true
