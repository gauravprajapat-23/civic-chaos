# CC-029 Dynamic Event Director

`CivicEventDirector` selects data-defined civic events using seeded RNG and sorted candidate IDs. Each event defines `id`, `cost`, `cooldown`, `duration`, `tags` and minimum integer metric `conditions`. `advance_to(tick, metrics)` releases expired budget, filters eligible events, then starts at most one event per call. Events sharing a tag cannot overlap; the same event cannot run concurrently with itself. `max_concurrent` limits active events. The budget is refunded when an event ends.

`snapshot()` exposes state and RNG position for persistence or debugging; state restoration and live incident spawning are not yet implemented. Conditions currently require all metric thresholds to be met. The headless test verifies seeded replay, cooldowns, budgets and conflicting-event exclusion.

Run: `godot --headless --path . --script res://tests/event_director_test.gd`.
