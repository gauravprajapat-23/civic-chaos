# TRAFFIC-FIX-12 — Head-of-Line Blocker Detection & Marshal Wrong-Way Clearance

**Date:** 2026-11-16  
**Existing branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source, new UI, regressions committed; Windows Godot import/tests, gameplay and Android QA pending.

## User goal and observed issue

The Wrong Way mission has repeatedly remained unfinished while physical queues accumulate at the central junction, even after player signal changes and several previous traffic admission/follower priority fixes. The user wants the **traffic marshal to remove the offending wrong-way car from the road easily**, rather than waiting for an unreliable tow truck to traverse the entire jam.

Two separate issues must not be confused:
- **The offender:** A scripted, wrong-way-facing car deliberately blocks the west approach. The marshal is the lawful way to remove this car after evidence and report.
- **The follower chain:** Actual vehicles can remain stopped behind the offender or one another. Green lights cannot safely move cars through physical colliders. Real queue progress, not the button press, must drive civic reputation.

## Implemented gameplay — Clear Wrong-Way Vehicle

Files: `scripts/ui/traffic_marshal_panel.gd`, `scripts/core/main.gd`, `scripts/civic/wrong_way_live_mission.gd`

1. At the existing roadside Traffic Marshal post (E / mobile USE, within its 3.5m interaction range), open the panel. A new **Clear Wrong-Way Vehicle (Marshal)** button sends an action to the actual `CivicWrongWayLiveMission`.
2. **Eligibility:** player must first inspect the queue at the Wrong Way evidence post, file the actual incident report, and wait for the officer to physically arrive so the incident state is `INTERVENTION`. Unreported or unauthorised work is refused with feedback.
3. **Worksite safety:** the actual physical offending vehicle and any currently active municipal tow are checked at their *existing* world positions with a 1m sphere on collision layers 2|4|8, excluding only their own collision shapes. A player, pedestrian or other car at the immediate removal worksite prevents the action. If the tow is already in the central intersection, occupied crosswalk reservations also block removal. No other actors are teleported, made non-colliding or removed.
4. The authorised marshal secures the car for **2 seconds of uninterrupted worksite clearance**. New interference pauses the process, rather than causing an unsafe overlap.
5. On verified completion, the existing `_finish_tow_convoy` / `tow_recovered_on_site` flow retires the wrong-way offender and any tow truck from their **actual positions**, releases municipal stopline service priority, reopens the incident lane, and starts the existing bounded discharge window for real queued followers.
6. **Mission completion remains honest:** removing the offender alone does not award reputation. At least two real followers must advance beyond the old blockage and the actual stopped queue must remain clear for 12 recovery frames. Repeated button presses cannot pay twice.
7. The short manual-clearance progress is runtime-only. If a checkpoint is written during the two-second action, loading it safely resumes before the request; re-use the marshal button. Completed removal writes the existing checkpoint-compatible tow-completed/recovered-on-site fields, without a new save version.
8. The old automatic tow option remains a fallback, but is no longer the only way to authorise vehicle removal.

Gameplay diagnostic events: `CIVIC_MARSHAL_CLEARANCE phase=requested` and `phase=completed`.

## Implemented diagnosis — front-most physical blocker

File: `scripts/traffic/traffic_spawner.gd`

`head_of_line(vehicle)` follows the actual chain of stopped vehicle collisions and same-lane leads, stopping at the front-most car or the first non-vehicle physical collider. It returns the chain, head vehicle, route lane, precise distance, head stop reason, physical collider or cycle. It uses an at-most 24-deep visited set; never mutates vehicle positions, collision bodies, signal states, mission events or reputation. Once a stopped background vehicle has held the same non-red reason for 600 ticks (30 seconds), `CIVIC_HEAD_OF_LINE` prints a concise structured trace so the developer can identify which **first car** actually prevents queue release.

## New tests

- `tests/traffic_fix_12_marshal_removal_test.gd`: refuses before report, refuses before marshal arrival, refuses real layer-8 pedestrian, accepts only authorised safe removal, waits through physical collection, verifies blocker removal and follower discharge stage without invented mission reward.
- `tests/traffic_fix_12_head_of_line_test.gd`: detects the real front-most of three stopped cars, leaves all cars unchanged, then confirms it resolves to the next car once the former head finishes.
- Existing relevant regression gate includes `traffic_fix_11d_wrong_way_follower_release_test.gd`, `traffic_fix_11c_tow_priority_lifecycle_test.gd`, `traffic_fix_11b_municipal_junction_priority_test.gd`, `traffic_perf_11a_tow_starvation_test.gd`, `traffic_perf_11e_city_admission_test.gd`, `wrong_way_tow_service_priority_test.gd`, `traffic_spawner_test.gd`, `world_junction_checkpoint_test.gd`.

## Windows Godot verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Git update failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$code = $LASTEXITCODE
$log | Out-Host
if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) {
    throw "Godot import failed"
}

$tests = @(
  "traffic_fix_12_marshal_removal_test.gd",
  "traffic_fix_12_head_of_line_test.gd",
  "traffic_fix_11d_wrong_way_follower_release_test.gd",
  "traffic_fix_11c_tow_priority_lifecycle_test.gd",
  "traffic_fix_11b_municipal_junction_priority_test.gd",
  "traffic_perf_11a_tow_starvation_test.gd",
  "traffic_perf_11e_city_admission_test.gd",
  "traffic_fix_09_single_approach_rules_test.gd",
  "wrong_way_tow_service_priority_test.gd",
  "traffic_spawner_test.gd",
  "world_junction_checkpoint_test.gd"
)
foreach ($test in $tests) {
  Write-Host "Running $test" -ForegroundColor Cyan
  $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
  $code = $LASTEXITCODE
  $log | Out-Host
  if ($code -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
      -not ($log | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "TRAFFIC-FIX-12 focused gate PASSED!" -ForegroundColor Green
```

## Acceptance still open

- [ ] User launches a fresh Wrong Way mission, inspects and reports offender, waits for marshal to physically intervene.
- [ ] User opens roadside Traffic Marshal panel and taps **Clear Wrong-Way Vehicle (Marshal)**. The offending car is removed locally after an observable two-second safety interval; no full tow journey required.
- [ ] People or background cars standing inside the actual removal site prevent unsafe removal. Tow already in crossing + occupied crosswalk also refuses; no instant collision bypass.
- [ ] Queued followers physically advance after removal. Civic reward appears only after at least two genuinely resume and the queue is sustained clear. No double award.
- [ ] All unrelated NPC cars still obey signals, real pedestrian/collider checks and temporary city congestion admission limits.
- [ ] `CIVIC_HEAD_OF_LINE` identifies any actual remaining front blocker instead of misleading repeated rear follower logs.
- [ ] F5/F9 before/after player removal retains complete incident state without phantom tow, and Android touch UI can activate the button.
- [ ] Five-minute gameplay report shows new ordinary cars are paced and the completed background traffic count increases.

**No local Godot or Android runtime is available to the GitHub edit environment. Source and tests are not verification; keep this issue OPEN until the user's local result passes. No GitHub Actions manually triggered.**
