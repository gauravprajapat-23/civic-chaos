# CC-016 Hierarchical Vehicle Behavior

`CivicVehicleBehavior` manages navigation (routing/approach), junction access (waiting/crossing) and recovery, with completion as a terminal state. `configure(agent, reservation_manager, vehicle_id)` assigns dependencies. `advance_fixed(tick, delta, signal_green)` evaluates a deterministic state transition; callers advance the vehicle separately.

At a configured stop distance from the end of the inbound lane, vehicles enter waiting. A green signal and an exclusive reservation for the `center` conflict zone are required before entering crossing. A competing vehicle cannot reserve an occupied zone. Once the agent advances to its outbound lane, occupancy is released. `interrupt(reason)` stops the agent and releases its reservation; invalid routes enter recovery.

This is an initial single-conflict-zone controller for the test junction. Stop distance is currently a behavioral trigger rather than a physical stop-line travel clamp; a fast-moving vehicle may overshoot without an additional movement constraint. The junction still needs signal mapping and integration of behavior controllers with spawned agents before realistic safe traffic is verified.

Test: `godot --headless --path . --script res://tests/vehicle_behavior_test.gd`.
