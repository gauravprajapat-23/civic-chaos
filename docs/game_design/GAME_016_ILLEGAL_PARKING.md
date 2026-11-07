# GAME-016 — Footpath First: Illegal Parking and Pedestrian Obstruction

Date: 2026-11-07 · Branch: `fix/regression-nov05`
Status: **Source committed, Godot 4.7.2 runtime acceptance pending**.

## Playable civic scenario

After the player completes the **Footpath Blocked** tutorial and **Wrong Way, Wrong Day** mission, the game stages another incident on the north footpath, east of Market Chowk.

- An orange parked vehicle is an actual `CivicVehicleAgent` scene with a physical `CollisionBody` on the 2 m-wide pedestrian sidewalk near x=24, z=-5.
- A green-clothed witness is an actual `AnimatableBody3D` with a pedestrian capsule and a swept physics shape test. They start walking towards the obstruction and can be stopped by the parked car's collision body. No synthetic pedestrian delay or throughput counter is credited as real.
- The player approaches a turquoise-clothed **Vehicle Owner** near x=20, z=-8.2 (pedestrian-side interaction layer 16). E/USE opens the existing incident card. **Inspect Evidence** is available only after physical witness blockage; **Ask owner to relocate** becomes available only after inspection.
- An accepted owner request uses the existing player `CivicInteractionService` reporting validation, advances the incident to `ESCALATED`, and records the `owner_contacted` mission objective. Repeated requests or remote interactions are denied.
- The cooperating owner visibly walks toward the car. The intervention phase is recorded after the owner physically arrives, not on button click.
- The car follows a deliberately marked two-segment relocation route at bounded speed, from the blocked footpath into an off-path bay near x=36, z=-8.5. A **solid car collision shape** stays with the vehicle throughout the move; interpolated swept-overlap checks refuse traversal through real pedestrians, players, buildings, other cars or props.
- The witness must subsequently travel past x=27 (the former blocked location) while the walking path is physically clear for several frames. Only then is the incident resolved, civic scores applied and the 75-point one-time mission reward issued.
- The car stays parked as physical world geometry in the designated bay after completion. Nothing is deleted just to make a score increase happen.

## Reuse and code files

| File | Purpose |
|---|---|
| `scripts/civic/illegal_parking_mission.gd` | Physical parked car, moving witness, owner dialogue/action, supervised relocation, measured pedestrian reopening, civic outcome |
| `scripts/civic/parking_owner.gd` | Visible owner actor and E/USE interaction sensor |
| `scripts/core/main.gd` | Start GAME-016 after real wrong-way mission completion; connect incident card/mission guide/HUD |
| `scripts/ui/civic_incident_card.gd` | Permit the explicit `request_owner` action and owner-specific label while keeping generic `report` unchanged |
| `tests/illegal_parking_live_test.gd` | Actual pedestrian collision, owner consent, bounded movement, measured reopening, one-time reward |
| `tests/illegal_parking_obstacle_test.gd` | Relocation stops at world obstruction, no premature reward, resumes after obstacle is removed |
| `tests/parking_owner_card_test.gd` | New owner action and backward compatibility with normal report buttons |
| `tools/run_regression.py` | All three new tests registered; strict Godot `ERROR:/SCRIPT ERROR:` detection unchanged |

## User flow

1. Complete the two earlier tutorial/civic missions.
2. Watch the pedestrian reach and stop at the orange car on the east-side north footpath. The mission guide shows the genuine car/owner waypoint.
3. Approach the vehicle owner near the sidewalk. Press E/USE to open the card.
4. Choose **Inspect Evidence**; then choose **Ask owner to relocate**. Do not enter the car's moving route.
5. Watch the owner walk to the car, then the car drive slowly to the marked green bay.
6. Only after the pedestrian actually passes the old blocked spot should the mission show completion, increase civic scores and award its 75 points.

## Design constraints and current limitations

- The incident is **cooperative**, not a police-action simulator. The player cannot seize, tow or directly move someone else's car; consent and state checks are required.
- The first marked bay/route is a prototype in fictional Nagripur. This is not a representation of real municipal parking authorization, traffic law, or towing procedure.
- Existing background walkers remain managed by `CivicDistrictPedestrians`. The new dedicated physical witness demonstrates the causal obstruction/recovery loop. A shared pedestrian-network rerouter for all NPCs is a future system.
- The simple owner actor has a visible capsule/label but no skeletal animation or audio. A refusal/escalation choice, owner pathfinding and service dispatch variations are future features.
- Safety movement uses swept collision probes over the relocation trajectory. It does not provide a full traffic authority/road closure schedule. Real-play integration, collision margin tuning and mobile performance still require inspection.
- **GAME-017 prerequisite:** checkpoint persistence for the new physical witness/owner/vehicle is not implemented. Rather than silently dropping this mission from GAME-014 save files, F5/F9 show an explicit guard while a parking scenario exists, including after completing it. Restart the level to load an older supported checkpoint. This limitation must be addressed before a durable multi-incident campaign release.
- The user's previous GAME-014 completed-checkpoint validation failure was addressed in source at `f12ecbe` with terminal-state diagnostics; the corrected Godot run has **not yet been supplied**. Do not label that gate passing merely because GAME-016 code was added.

## Focused acceptance commands (Windows PowerShell)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
$focused = @(
  "illegal_parking_live_test.gd",
  "illegal_parking_obstacle_test.gd",
  "parking_owner_card_test.gd",
  "wrong_way_checkpoint_test.gd"
)
foreach ($test in $focused) {
  & $godot --headless --path . --script "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { throw "Focused test failed: $test" }
}
python tools/run_regression.py --godot $godot --timeout 90 --report build/game-016-illegal-parking-report.json
Write-Host "Exit code: $LASTEXITCODE"
```

Expected focused test success markers (not yet observed):
- `CIVIC_CHAOS_ILLEGAL_PARKING_LIVE_PASS`
- `CIVIC_CHAOS_ILLEGAL_PARKING_OBSTACLE_PASS`
- `CIVIC_CHAOS_PARKING_OWNER_CARD_PASS`

**Acceptance state**
- [x] Code and regression scenarios committed on the named branch
- [x] Source-level wiring checks completed
- [ ] Local Godot import and focused tests pass
- [ ] Full strict regression suite passes
- [ ] PC manual walkthrough confirms pedestrian stopping/recovery and owner relocation
- [ ] Android interaction controls and performance checked
- [ ] GAME-017 persistence and resume semantics implemented

No GitHub Actions were manually dispatched. Push-triggered workflows may run automatically. The separate report filename preserves the user's locally modified `build/regression-report.json`.
