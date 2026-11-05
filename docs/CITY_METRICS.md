# CC-026 Civic Reputation and City Metrics

`CivicCityMetrics` tracks safety, efficiency, trust and cooperation as deterministic integer scores from 0 to 1000, initialized at 500. `apply_outcome(event_id, tick, changes, reason)` accepts named dimension deltas up to 100 points per event, clamps scores, rejects stale ticks and prevents duplicate event scoring. `reputation()` returns the equally weighted average. `snapshot()` and `restore(data)` support JSON save persistence.

Use stable unique IDs such as `incident:<id>:resolved` or `mission:<id>:reward` so replays and duplicate reward requests cannot inflate city scores. Changes must be based on actual outcomes, not player proximity or arbitrary NPC judgments. Game event wiring and UI dashboards remain future work.

Test: `godot --headless --path . --script res://tests/city_metrics_test.gd`.
