class_name SimulationDirector
extends Node
## Orders simulation systems deterministically on logical ticks.

signal simulation_tick(tick_index: int, fixed_delta: float)

@export_range(1, 120, 1) var ticks_per_second: int = 20
@export var simulation_seed: int = 12345

var clock: SimulationClock
var random_streams: SeededRandom
var _systems: Array[Callable] = []

func _ready() -> void:
    clock = SimulationClock.new(ticks_per_second)
    random_streams = SeededRandom.new(simulation_seed)
    clock.tick_started.connect(_on_tick_started)

func _physics_process(delta: float) -> void:
    clock.advance(delta)

func register_system(callback: Callable) -> void:
    if not _systems.has(callback):
        _systems.append(callback)

func unregister_system(callback: Callable) -> void:
    _systems.erase(callback)

func set_simulation_paused(value: bool) -> void:
    clock.paused = value

func restart_simulation() -> void:
    clock.reset()
    random_streams.reset()

func _on_tick_started(tick_index: int, fixed_delta: float) -> void:
    for callback in _systems:
        if callback.is_valid():
            callback.call(tick_index, fixed_delta)
    simulation_tick.emit(tick_index, fixed_delta)

## World clock state can only be applied to a stopped SimulationDirector
## inside the GAME-019 restore transaction.
func checkpoint_state() -> Dictionary:
    return clock.snapshot() if clock != null else {}

func checkpoint_valid(data: Variant) -> bool:
    return clock != null and clock.can_restore(data)

func restore_checkpoint(data: Variant) -> bool:
    if clock == null or is_physics_processing() or not clock.can_restore(data):
        return false
    return clock.restore(data)
