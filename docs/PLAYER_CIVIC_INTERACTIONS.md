# CC-027 Player Civic Interactions

`CivicInteractionService` validates player inspection, reporting and incident resolution. `inspect(incident_id, distance_m)` returns an immutable copy of incident data only within 3m. `begin_action(player_id, incident_id, action, distance_m, permissions)` stages a permitted action, `cancel(player_id)` drops it, and `confirm(player_id, tick, distance_m, permissions)` rechecks distance, permission and incident state before applying a transition.

Reporting moves an active incident to escalated. Resolution is permitted only after a separate intervention step; the player cannot bypass it. The interaction is consumed on confirmation, even if rejected, preventing stale requests.

This is a permission-checked interaction service, not yet wired to a 3D interactable or HUD. The world must derive permissions from actual player roles and compute distances from world positions, never from untrusted client-supplied values. A mission event can be dispatched only after a successful confirmation.

Test: `godot --headless --path . --script res://tests/player_civic_interactions_test.gd`.
