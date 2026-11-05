# CC-022 Illegal Parking and Capacity Reduction

`CivicParkingCapacity` models per-lane throughput with a deterministic integer queue. `register_lane(id, capacity_per_tick)` establishes baseline throughput. `park_illegally(id, offender_id, blocked_fraction, tick)` opens a civic incident and reduces service capacity to `floor(base_capacity * (1 - blocked_fraction))`. `advance_to(tick, demand_by_lane)` adds arrivals and serves up to capacity. `remove_obstruction(id, tick)` restores throughput and records intervention. `resolve(id, tick)` closes the incident only after the queue drains.

The scenario compares blocked and unblocked lanes under identical demand. This is a macro congestion model; vehicle-level obstruction geometry, following sensors, parking visuals and real traffic-spawner demand remain to be integrated.

Test: `godot --headless --path . --script res://tests/parking_capacity_test.gd`.
