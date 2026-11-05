# CC-012 Intersection Conflict-Zone Reservations

`CivicIntersectionReservations` grants half-open logical tick windows for one or more named conflict zones. Overlapping windows on the same zone cannot be granted to different vehicles. Distinct zones can be reserved concurrently. Ties resolve deterministically in caller request order; callers should submit requests in stable vehicle-ID order.

`request(vehicle_id, zones, start_tick, end_tick)` returns `{granted: bool, reason: String}`. Reasons: `granted`, `existing`, `invalid_request`, `invalid_zones`, `conflict`, `occupied`.

`occupy(vehicle_id, zone)` requires a currently valid reservation; occupancy persists beyond reservation expiration until `release(vehicle_id, zone)` by the owner. `cancel(vehicle_id)` removes reservations but does not remove physical occupancy. `advance_to(tick)` expires old reservations and rejects backward time. `reset()` clears state.

The four-way junction now owns the reservation manager and advances it with simulation ticks. Vehicle crossing requests, route-specific conflict-zone mapping, stop-line enforcement and collision avoidance are separate follow-up work.

Test: `godot --headless --path . --script res://tests/intersection_reservations_test.gd`.
