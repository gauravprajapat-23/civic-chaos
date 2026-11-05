# Vehicle Profiles and Lane-Following Agents — CC-009

`CivicVehicleProfile` defines acceleration, braking, maximum speed, steering-rate placeholder and vehicle-class mask.

`CivicVehicleAgent.configure(graph, route, profile)` checks the graph and every directed transition. `advance_fixed(delta)` advances along each lane's world-space polyline using acceleration/braking and speed limits. It stops at the final endpoint, emits `route_completed`, and rejects invalid or disconnected routes.

Use fixed simulation ticks (for example 20Hz) for deterministic motion. The current vehicle uses a box placeholder and snaps orientation to the lane tangent. Turn-rate-limited steering, car-following, collision avoidance and signal compliance remain follow-up work. A `StaticBody3D` is included for prototype collision geometry; movement is kinematic, not rigid-body physics.

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/vehicle_agent_test.gd
```
