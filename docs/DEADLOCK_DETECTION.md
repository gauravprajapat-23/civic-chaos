# CC-023 Wait-for Graph Deadlock Detection

`CivicDeadlockDetector` tracks directed vehicle-to-vehicle waits. `observe(vehicle_id, blocker_id, tick, "vehicle")` records a blocking relationship; `clear_wait(vehicle_id)` removes it. Signal waits, unowned obstacles and invalid self-waits are intentionally excluded. `advance_to(tick)` advances the monotonic simulation clock. `detect_cycles()` finds deterministic cycles and reports only cycles whose every edge has remained unchanged for at least `minimum_wait_ticks` (default 20 ticks, one second at 20 Hz).

Use the traffic sensor and intersection reservation system to supply actual vehicle-to-vehicle blockers. Clear edges when a vehicle moves, despawns or no longer has a blocker. The detector does **not** automatically move vehicles or grant reservations; recovery policy and live simulation integration remain separate.

Test: `godot --headless --path . --script res://tests/deadlock_detector_test.gd`.
