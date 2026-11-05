# CC-020 Civic Incident Lifecycle

`CivicIncidentManager` tracks civic incidents through `active -> escalated -> intervention -> resolved`, with an optional direct `active -> intervention` transition and `intervention -> escalated` if a response fails. A resolved incident is terminal.

`create_incident(kind, source_id, tick, location_key)` suppresses duplicate unresolved incidents with the same kind, source and location. `transition(id, next_state, tick, cause)` enforces legal state changes and nondecreasing simulation ticks, recording the causal reason for each event. `snapshot()`, `to_json()` and `from_json()` support persistence and replay inspection.

This component is a pure lifecycle service. Integration with NPC observations, player interventions, civic scoring, game save slots and scene presentation is future work.

Test: `godot --headless --path . --script res://tests/incident_lifecycle_test.gd`.
