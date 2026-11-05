# CC-021 Wrong-Side Driving Scenarios

`CivicWrongWayScenario.configure(graph, reservations, incidents, source_lane_id, connector_id)` adds a flagged illegal connector to the lane graph. Legal routing and normal vehicle configuration exclude flagged connectors; an explicit `enter_violation(offender_id, tick)` initiates the scenario without granting intersection access.

During an obstruction, `advance_to(tick, demand)` grows a deterministic synthetic queue. `intervene(tick)` records a traffic-marshal intervention and begins queue drainage; `resolve(tick)` closes the incident once the queue clears. `metrics()` provides congestion and recovery telemetry. The scenario is deterministic for the same tick and demand sequence.

**Scope:** This is a scenario service with simulated queue counts, not physical wrong-way vehicle navigation. Real NPC/vehicle visuals, spatial queues, emergency yielding, and safe routing back to legal lanes are still required. Never bypass reservation authorization to make an illegal connector traversable.

Test: `godot --headless --path . --script res://tests/wrong_way_scenario_test.gd`.
