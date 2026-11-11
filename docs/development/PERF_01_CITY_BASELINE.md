# PERF-01 — Measured traffic and pedestrian performance baseline

**Status: instrumentation staged, not yet executed in Godot.** This milestone applies the uploaded `performance-optimization` skill and its `references/profiling-and-budgets.md`: **measure -> identify CPU/GPU bound -> change one bottleneck -> remeasure on the same device**. Do not claim an FPS gain without before/after evidence.

## What is implemented

- `scripts/core/performance_capture.gd` (`CivicPerformanceCapture`): validates and bounds **real sampled** frame interval, engine process and physics time, pedestrian and traffic work-time averages, draw calls, static memory and NPC/car counts; reports mean, median, p95, min, max and sample counts. Reports explicitly expose `gpu_timing_available: false` and `performance_target_verified: false` rather than inventing GPU timings or claiming target FPS.
- `scripts/npc/district_pedestrians.gd`: optional `profile_movement_enabled` (defaults **false**) collects the duration in microseconds of an entire pedestrian `_physics_process` update. `movement_profile()` exposes a bounded 120-sample mean/peak and actual walker count. `reset_movement_profile()` clears it. Normal gameplay skips timing collection.
- Existing `CivicTrafficSpawner.work_budget.metrics()` already records bounded traffic work microseconds; its fleet size and throughput are sampled without modifying the spawner.
- `tools/profile_city_baseline.gd`: **explicit opt-in** `SceneTree` runner that loads `scenes/core/main.tscn`, warms up, samples actual Godot engine monitors and the two systems, and writes `user://civic-chaos-perf-baseline.json`. It does not patch the main scene, game save schema, visuals, physics, traffic or NPC pathfinding. The runner is for local performance observation only.
- `tests/performance_capture_test.gd`: checks numeric percentiles (nearest-rank median/p95), count and bounds, malformed sample rejection, metadata copy/immutability, max 3600 samples, absence of falsely claimed GPU/target data, and default-off/opt-in/disabled/reset pedestrian timing. Fixture numbers are explicitly **synthetic test data**, never an actual gameplay baseline.
- Required acceptance inventory rises to **104 mandatory Godot tests, 24 focused tests, 30 Python checks and 4 deterministic state replays**.

## Running the opt-in benchmark locally

**First:** finish exact-SHA AUD-001 Godot 4.7.2 verification and campaign/F5/F9 walkthrough. Do not activate unverified AI or UI changes to obtain a "better" benchmark.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch fix/aud-001-game024-gate-hardening
git pull --ff-only origin fix/aud-001-game024-gate-hardening

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

# Verify the telemetry math and default-off pedestrian probe:
& $godot --headless --path . --script res://tests/performance_capture_test.gd
if ($LASTEXITCODE -ne 0) { throw "Performance capture fixture failed" }

# Actual city logic in a headless run (NOT a GPU or real-device FPS result):
& $godot --headless --path . --script res://tools/profile_city_baseline.gd -- --frames=1800 --warmup=120 --stride=5

# For representative graphics data, run without --headless and capture the
# same scene and seed on the actual machine/device.
& $godot --path . --script res://tools/profile_city_baseline.gd -- --frames=1800 --warmup=120 --stride=5
```

The report is written to **Godot's `user://civic-chaos-perf-baseline.json`**, not to the project repository or the checkpoint save. Find its exact path in the printed `CIVIC_CHAOS_PERFORMANCE_PROFILE_REPORT` line. The output includes the actual engine version, OS/display server, scenario, simulation seed, actor limits, viewport, warmup and sampling cadence, so recordings can be compared meaningfully.

### What each metric actually means

| Key | Meaning / caveat |
| --- | --- |
| `frame_interval_ms` | Monotonic wall-clock interval between `process_frame` callbacks; includes wait/scheduling and is **not** a CPU or GPU duration |
| `process_ms` | `Performance.TIME_PROCESS` multiplied by 1000; engine process CPU duration |
| `physics_ms` | `Performance.TIME_PHYSICS_PROCESS` multiplied by 1000; engine physics CPU duration |
| `pedestrian_update_us` | Opt-in rolling per-physics-update pedestrian callback time (120-sample mean); adds small measurement overhead |
| `traffic_update_us` | Existing rolling traffic update microseconds reported by `CivicTrafficBudget` |
| `draw_calls`, `static_memory_bytes` | Godot monitor values. A headless display can report zero draw calls; **zero does not mean GPU work is free** |
| `cars`, `walkers` | Actual active scene actor counts, not assumed configured counts |
| `gpu_time_ms: null` | Deliberately not captured. Read **Godot Visual Profiler** on a windowed/device session before deciding CPU vs GPU optimization |

## Profiling protocol

1. Record device CPU/GPU, RAM, operating system, Godot 4.7.2 build, window size/scale, render backend, resolution, vsync, thermal state and release/debug mode. The CLI runner labels itself `windowed_cli_debug` or `headless_smoke_only`—neither is a verified Android release profile.
2. Run the identical **quiet district** and **crowded district** with known seed, cars and pedestrian counts. Do not change simulation settings between baseline and after.
3. Warm up and sample at least 30 seconds; the command measures 1800 rendered callbacks, whose real time depends on device FPS. If needed, increase `--frames` up to 18000; `--stride` determines sample cadence.
4. Record median and p95 frame interval, script and physics CPU, draw calls, static memory, pedestrian/traffic callback time, vehicle throughput, and actor counts. Capture GPU timing and render passes **separately with Godot Visual Profiler**.
5. Choose **one** measured bottleneck. If collision queries dominate, investigate pedestrian spatial neighbors or lower-rate queries; if draw calls/GPU dominate, investigate mesh/material sharing or MultiMesh. Do not do both simultaneously.
6. Re-run the exact scenario and report before/after numbers, p95 regressions, correctness, gameplay and collision behavior. Revert "optimizations" whose evidence does not improve frame timing.

**Reference goals, not claims:** 60 FPS desktop = 16.67 ms/frame; 30 FPS mobile = 33.33 ms/frame. A headless smoke test or synthetic fixture is never evidence that either target was achieved.

**Current limitation:** Neither Godot 4.7.2 nor Windows PowerShell is installed in the authoring environment, so **no real Civic Chaos performance metrics have been collected or FPS improvements claimed**. Existing PR #49 remains draft, and no GitHub Actions should run.

Related work: [#52](https://github.com/gauravprajapat-23/civic-chaos/issues/52), staged NPC utility [#50](https://github.com/gauravprajapat-23/civic-chaos/issues/50), staged mobile touch [#51](https://github.com/gauravprajapat-23/civic-chaos/issues/51).
