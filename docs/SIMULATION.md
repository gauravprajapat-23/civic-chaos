# Deterministic Simulation Core (CC-003)

## Clock
`SimulationClock` advances fixed logical steps at a configured tick rate (20 Hz default). `advance(delta)` may execute up to 8 ticks per call. It returns the number executed. The accumulator retains excess elapsed time, so long frames can take multiple updates to catch up. `step_once()` is useful for deterministic testing.

## Seeded random streams
`SeededRandom` creates a separate `RandomNumberGenerator` for each stable agent ID, derived from a root seed. An agent's random sequence is not changed by other agents consuming random values. `reset()` recreates the original sequences.

## Director
`SimulationDirector` is an ordinary Node (not an autoload). Place it in a world scene and register system callbacks in deterministic order. It drives logical ticks from `_physics_process`, emits `simulation_tick`, and provides pause/reset APIs. Consumers should not call `randomize()` or global random functions for simulation decisions.

## Replay contract
Record initial root seed, stable agent IDs, game version, tick rate, player commands indexed by tick, and relevant initial world state. Determinism is at the logical-decision level, not a promise of bit-for-bit physics across hardware.

## Validation
```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/determinism_test.gd
```
