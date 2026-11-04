# CC-024 Safe Deadlock Recovery

`CivicDeadlockRecovery.configure(detector, reservations, router)` wires the cycle detector, exclusive intersection reservations and legal lane router. `plan_recovery(cycle, positions, destinations, vehicle_mask, blocked_lanes)` verifies a stable detected cycle, evaluates vehicles in ascending ID order, and proposes a legal reroute avoiding other cycle members' current lanes. Attempts are bounded per vehicle; unrecoverable cases return `action=hold` rather than unsafe motion.

`repair_stale_reservation(vehicle_id, zone)` refuses to cancel reservations if the zone is occupied; it never grants access or releases an occupant. `acknowledge_recovery(vehicle_id)` clears a wait edge **only after** the caller verifies the maneuver completed.

This is a safe recovery *planner*, not a physical maneuver executor. The world must still validate clearance, acquire new reservations, apply the route and acknowledge successful movement. Automated tests cover confirmed cycles, occupied reservations and no-route failure. No reversing or teleporting is performed.
