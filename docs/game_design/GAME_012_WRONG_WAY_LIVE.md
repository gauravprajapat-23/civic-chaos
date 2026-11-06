# GAME-012 — Wrong Way, Wrong Day: live physical scenario
Date: 2026-11-06 | Branch `fix/regression-nov05` | Status: **CODE COMMITTED — GODOT 4.7.2 NOT RUN**

## What changed
- `scripts/civic/wrong_way_live_mission.gd`: stages a **real** `CivicVehicleAgent` offender facing and moving briefly against a legal incoming city lane, and a group of independently moving `CivicVehicleAgent` follower cars using the existing `CivicRoadGraph`, `CivicTrafficSensor`, vehicle profile, collision probes, and, in the actual scene, live city stop-line observation.
- The stage uses the **real west-to-center city lane** (roughly x=-46→0, z=0); no extra synthetic road system is introduced. Spawn checks reject existing physical occupancy; a failed stage can retry later without creating an orphan civic incident.
- The red offender remains a solid world vehicle obstruction. The follower cars brake/queue using real physical checks and longitudinal car-following. `stopped_count` counts cars **only after they have actually moved and then stopped**. It is never assigned from the old `queue_count += demand` simulation.
- `scripts/civic/wrong_way_report_marker.gd`: a yellow pedestrian-side report post, layer 16 (interactable; not a physical blocker), with E/USE label.
- A report requires a **visible, measured queue of at least two cars**, explicit inspection, proximity to the report post, and valid interaction state; duplicate reports are denied.
- Following a valid report, an actual visible `TrafficMarshal` (stylized 3D capsule) moves from the sidewalk to the scene; incident state advances to INTERVENTION **only after it arrives**.
- The obstruction is removed after authorized service delay, not merely when the user presses Report. Follower cars resume physical movement. The mission only resolves after at least two actual cars pass the former blockage and the incident approach's physically measured stopped queue stays clear for consecutive frames.
- The main 3D scene starts this mission **after** completion of the first Footpath Blocked tutorial; the existing evidence modal and city HUD are reused, with a separate live wrong-way stopped/peak queue display.
- Existing `CivicWrongWayScenario` remains untouched for deterministic, abstract unit tests; this GAME-012 version is player-facing and has actual colliders, vehicle movement and incidents.

## Acceptance evidence / testing
`tests/wrong_way_live_mission_test.gd` creates the actual city graph and vehicle scene nodes on a physical road support surface, then verifies:
- Wrong-way offender faces against legal lane, existing route and actual physical followers are used.
- No fabricated congestion at spawn and no early report/inspect.
- At least two previously-moving vehicles stop; displayed queue matches their physics state.
- Out-of-range report-post clicks are ignored, E/USE shows truthful nearby evidence.
- Authorized report is one-time, a visible marshal arrives before intervention is recorded.
- Blocker is actually removed and at least two real follower vehicles resume/past the blockage before completion.
- Queued telemetry isn't zeroed by the cleanup flag; one-time reputation and rewards.

**All above are test assertions added to the repository, not claims of passing outcomes.** Actual Godot runtime is unavailable to this GitHub editing session; Godot import, focused test, full regression and live playthrough are **NOT RUN**.

## Live walkthrough (after the latest tests pass)
1. Launch Civic Chaos, finish the orange **FOOTPATH BLOCKED** tutorial (inspect → report → service clears).
2. The next mission should activate. Follow the main road west toward the red **WRONG WAY** car and its vehicle queue.
3. Stand on the north-side sidewalk near **x=-20, z=-5.3** at the yellow report post. Do not walk into traffic.
4. Watch real cars stop, then look at the post and press **E** / **USE** to open the familiar civic card.
5. Choose **Inspect Evidence**, then **Report to Municipal Service**. Report stays locked until the real queue exists. Close the card.
6. Observe the 3D marshal approach; after authorized service, the offender is removed and cars begin moving past its old location.
7. Verify the HUD reflects real stopped/peak cars and the mission only completes after observed physical recovery.

## Limitations / next phases
- **GAME-013:** true authorized tow/escort along a legal verified route; the staged offender is currently queued for removal after marshal intervention, not driven along a full reroute.
- **GAME-014:** game-wide checkpoint persistence of the additional live scenario, released-car states and marshal position is not implemented. F5/F9 are intentionally blocked while this scenario exists, with an explanatory message, rather than silently save or load a mismatched world.
- **GAME-015:** detailed dialogue, failure/retry screen, service dispatch schedules and balancing are still future work.
- Existing city vehicles are owned by the main spawner; the mission owns **four actual additional vehicle instances** on the same city road graph. They are counted separately for this incident; main-city total traffic simulation remains independently managed. Integrated congestion/performance profiling remains outstanding.
- Actual moving-collision and signal behavior need game playtest and headless tests; no new issues may be marked resolved from source inspection alone.
- No GitHub Actions were manually dispatched; the repository's configured push workflow may run automatically.

## Local Godot commands (PowerShell)
```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/wrong_way_live_mission_test.gd
python tools/run_regression.py --godot $godot --timeout 60 --report build/game-012-wrong-way-report.json
Write-Host "Exit code: $LASTEXITCODE"
```
This report path avoids overwriting `build/regression-report.json` if it is modified locally.
