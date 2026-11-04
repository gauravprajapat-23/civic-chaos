# CC-010 Car Following and Obstacle Detection

`CivicTrafficSensor.nearest_lead(follower, vehicles, obstacles)` finds the nearest active vehicle or static obstacle ahead on the same lane. Static obstacles use `{lane_id, distance_m}`. Observations contain `detected`, `gap_m`, `lead_speed_mps`, and `object_id`. The current sensor covers the same lane only; junction conflict zones and look-ahead across multiple lanes are future work.

`CivicVehicleAgent.set_lead_observation(gap_m, lead_speed_mps)` sets the next fixed-tick observation. `clear_lead_observation()` removes it. The follower computes a conservative braking-speed bound, and hard-clamps travel to preserve the configured minimum longitudinal gap. This avoids overlaps even with a stationary obstacle, but instantaneous hard clamping can cause unrealistic emergency braking if sensors update late.

All vehicle advances should use the same fixed-step simulation clock. For multiple agents, sample observations from a single snapshot before advancing any agents to avoid order-dependent behavior.

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/car_following_test.gd
```
