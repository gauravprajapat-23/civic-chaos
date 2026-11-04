# CC-011 Traffic Signal Phases

`CivicTrafficSignalController` is a deterministic six-phase fixed-step controller:

1. North/South green
2. North/South amber
3. All-red clearance
4. East/West green
5. East/West amber
6. All-red clearance

Default durations: green 12s, amber 3s, all-red 2s. A complete cycle is 34 seconds. `advance_fixed(delta)` supports multi-phase advances and `reset()` restores the first phase. `aspect_for_approach("N"|"S"|"E"|"W")` returns red/amber/green. Unknown approaches fail safe to red.

The signal controller models phase state, not vehicle compliance. Vehicle stopping at stop lines and violation detection will be implemented in later traffic issues. The junction scene now owns a controller advanced by the simulation clock.

Run `godot --headless --path . --script res://tests/signal_phases_test.gd`.
