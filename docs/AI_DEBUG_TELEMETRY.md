# CC-033 AI debug overlay and telemetry export

F3 toggles the developer overlay; F4 exports recorded telemetry to `user://civic_ai_telemetry.json`. `CivicDebugTelemetry.record(tick, traffic, routes, reservations, decisions, deadlocks, timing)` requires strictly increasing ticks and JSON-safe dictionaries. It retains the latest 512 samples. Export schema: `{"schema_version":1,"sample_count":N,"samples":[...]}`.

`CivicDebugOverlay.record_snapshot(...)` updates the overlay with actual supplied snapshots. Integrators must pass live route, reservation, utility-decision, deadlock and timing measurements; these are **not yet wired** to the running simulation. The overlay currently shows an explicit waiting message rather than invented data. F4 can export an empty valid document.

Run `godot --headless --path . --script res://tests/debug_telemetry_test.gd`. Manual scaling, gameplay sampling and export checks remain outstanding.
