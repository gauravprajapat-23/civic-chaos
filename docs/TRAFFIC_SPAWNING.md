# CC-013 Traffic Spawning and Metrics

`CivicTrafficSpawner` creates seeded vehicle routes from four inbound lanes through the four-way test junction. `configure(graph, seed)` resets traffic and counters. `advance_fixed(tick, delta)` updates traffic at the simulation clock's fixed tick, samples same-lane lead vehicles, despawns completed routes, and attempts a spawn every `spawn_interval_ticks`.

`try_spawn()` checks the maximum active cap, validates directed route transitions, and rejects vehicles if the selected entry lane lacks `spawn_clearance_m` clearance. `metrics()` returns active count, queue count (speed below 0.2 m/s), cumulative spawned/completed/rejected counts, cumulative stopped-time delay, and average completed throughput per minute. Throughput assumes a 20Hz simulation clock.

The first implementation targets the four-way test graph (entry IDs 1,3,5,7), not arbitrary city networks. Cross-lane junction conflicts and traffic-light compliance are not enforced by this spawner yet; reservation and signal systems are available separately.

Test with `godot --headless --path . --script res://tests/traffic_spawner_test.gd`.
