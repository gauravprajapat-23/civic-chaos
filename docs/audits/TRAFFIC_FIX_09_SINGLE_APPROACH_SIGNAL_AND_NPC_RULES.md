# TRAFFIC-FIX-09 — One-Side-at-a-Time Central Signals & NPC Road Rules

**Date:** 2026-11-16  
**Branch:** `fix/aud-001-game024-gate-hardening`  
**Status:** Source and regression tests committed; Godot 4.7.2 and Android live acceptance pending.

## User feedback and observed issue

Latest screenshot showed an NS/EW city junction where two opposite signal heads appeared green together; users want one approach at a time, with intentional civic NPC rule-breaking as playable incidents rather than accidental background traffic collisions. The prior central controller was deliberately paired **NS_GREEN** / **EW_GREEN**; that was code-defined behavior, not necessarily an incorrectly illuminated signal. The screenshot also contains cars queued at the zebra crossing, so flow and actual physical blockers still require independent verification.

## Implemented central-junction behavior

- **Playable expanded city only:** `scripts/world/junction_scene.gd` enables `CivicTrafficSignalController.enable_single_approach_mode()`. Test-only and legacy isolated junctions retain the original paired controller mode by default, keeping existing regression fixtures meaningful.
- **Four separate green turns:** N_GREEN -> N_AMBER -> ALL_RED_N -> E_GREEN -> E_AMBER -> ALL_RED_E -> S_GREEN -> S_AMBER -> ALL_RED_S -> W_GREEN -> W_AMBER -> ALL_RED_W -> repeat.
- The usual 12-second green, 3-second amber and 2-second all-red remain deterministic. At any moment, **no more than one of N,E,S,W has green**. This is a requested game traffic policy, not a claim that all real-world intersections use only one direction.
- **Single authority:** `scripts/world/street_furniture.gd` already reads `aspect_for_approach("N"|"E"|"S"|"W")` for each visible signal lamp; `scripts/traffic/traffic_spawner.gd` uses that same controller when determining background car stop-line holds, central priority and municipal service permission. No separate visuals-only traffic clock.
- **NPC driver compliance:** All ordinary traffic still waits on red and amber before stop lines, respects physical player/pedestrian colliders and central occupancy, and continues through after crossing commits to avoid freezing in a changing signal. There is no random uncontrolled red-light running that could endanger pedestrians. Existing scripted illegal parking / Wrong Way are the intentionally reportable rule violations for civic-sense gameplay.
- **Pedestrians:** a walker entering an EW- or NS-conflicting central crosswalk must see *both* opposing approaches red, with at least 13 seconds until either next green. Existing walkers retain physical protection; they cannot be removed merely to switch signals.
- **Traffic Marshal:** panel now contains four individual direction buttons (N,E,S,W), but safe player control can shorten only the **next** approach's turn after the current green has run at least four seconds. Amber and all-red cannot be skipped and crossing/vehicle occupancy still veto the change. Selecting a future direction out of order produces an explanatory message. ROAD-GAME-01 measured clearance rewards remain unchanged.
- **Checkpoints:** existing snapshot `schema_version=1` retains the additional optional `single_approach_mode` flag and can load all 12 new phases. A valid older paired-mode phase can be migrated into the single-approach equivalent N or E phase during restore; existing background car/mission saves still require normal physical validation. An incompatible single-approach snapshot cannot silently restore into a paired test controller. No new reward fields.

## Code files

- `scripts/traffic/traffic_signal_controller.gd` — optional 12-phase single-direction mode; correct aspects, time-to-green, snapshots and guarded manual shortening
- `scripts/world/junction_scene.gd` — activate exclusive direction in expanded playable city
- `scripts/npc/district_pedestrians.gd` — opposing-head red and safe crossing entry window
- `scripts/civic/traffic_marshal_control.gd` — one-direction gated player commands
- `scripts/ui/traffic_marshal_panel.gd` — four individual direction buttons
- `scripts/core/main.gd` — short in-game four-direction cycle guidance
- `tests/traffic_fix_09_single_approach_rules_test.gd` — four full cycle turns and NPC stop lines, crosswalk restrictions, snapshot JSON and legacy migration
- `tests/traffic_fix_09_visual_marshal_test.gd` — correct visible green head, amber/all-red, safe manual request and pedestrian veto

## Local Windows gate

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$branch = "fix/aud-001-game024-gate-hardening"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin $branch
if ($LASTEXITCODE -ne 0) { throw "Git fetch failed" }
git merge --ff-only FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "Merge failed" }

$log = & $godot --headless --path . --editor --import --quit 2>&1
$exitCode = $LASTEXITCODE
$log | Out-Host
if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:')) { throw "Import failed" }

$tests = @(
  "traffic_fix_09_single_approach_rules_test.gd",
  "traffic_fix_09_visual_marshal_test.gd",
  "signal_phases_test.gd",
  "city_signal_stop_line_test.gd",
  "traffic_game_02_manual_signal_test.gd",
  "traffic_fix_06_axis_crossing_release_test.gd",
  "traffic_fix_06_pedestrian_entry_window_test.gd",
  "traffic_fix_08_central_spillback_test.gd",
  "traffic_fix_07_cross_fleet_junction_test.gd",
  "world_junction_checkpoint_test.gd",
  "traffic_spawner_test.gd"
)
foreach ($test in $tests) {
  Write-Host "Running $test" -ForegroundColor Cyan
  $log = & $godot --headless --path . --script "res://tests/$test" 2>&1
  $exitCode = $LASTEXITCODE
  $log | Out-Host
  if ($exitCode -ne 0 -or ($log | Select-String 'SCRIPT ERROR:|ERROR:') -or
      -not ($log | Select-String '_PASS')) { throw "FAILED: $test" }
}
Write-Host "TRAFFIC-FIX-09 focused gate passed" -ForegroundColor Green
```

## Live acceptance

- [ ] Capture visible signals at N/E/S/W turns. Verify only *one* of the four central heads has green, all others red, and amber/all-red occur between turns.
- [ ] Check NPC cars in all four approaches. Red/amber queues remain behind stoplines; green approach uses junction only if downstream lane is free. No cars enter perpendicular conflict zones concurrently.
- [ ] A car already inside junction clears even when the phase changes (do not freeze in intersection).
- [ ] NPC walkers do not enter against either opposing vehicle head, but crossing occupants remain physically protected if they have already entered.
- [ ] Traffic Marshal one-direction request waits for minimum green, follows cycle order and cannot skip amber/all-red or ignore people in crossing.
- [ ] Play Wrong Way and Illegal Parking missions. Intentional violations remain physical and reportable, while unintentional routine NPC signal violations should be logged as defects.
- [ ] Benchmark sustained traffic flow for at least 5 minutes; switching from two approaches to one can **reduce raw junction throughput**. Do not claim congestion fixed until actual queues drain in the live game.
- [ ] Save/load both current and older checkpoints, including a mid-clearance save.
- [ ] Build Android debug APK after tests, verify visually at 8/12/20 cars.

**Source committed; Godot execution not available in this coding session.** Keep central traffic flow and mission completion audits open until real PC/Android results pass.


## Explicit remaining scope — Outer intersections and new civic violations

**OUTER-SIGNAL-10 is still OPEN.** The outer 24 noncentral crossroads use `CivicOuterIntersectionPriority` (two-axis 120-tick green/40-tick clearance at 20 Hz) and `CivicOuterTrafficLights` (48 total axis-specific heads). They are *not* driven by the central `CivicTrafficSignalController`. This patch does not claim single-direction greens outside the central crossing; implementing four exclusive outer heads requires replacing the outer fixed-tick policy and upgrading `outer_intersection_priority_test`, `outer_intersection_movement_test`, and `outer_intersection_restore_test` together. Keep deterministic safe checkpoint reproduction as an explicit gate before exposing the outer changes in Android.

**NPC-VIOLATION-01 is OPEN for deliberate new violations.** Current civic gameplay already includes intentionally illegal Wrong Way and Illegal Parking actors with evidence, reporting and authorized resolution. Those *are not* normal background vehicles accidentally running red. An additional intentional red-light violator mission, if developed, must record a single physically observable attempt, not force random traffic through an occupied crossing; verify player investigation, officer intervention, penalty/reputation idempotency and pedestrian safety before enabling it. Unintentional NPC red-light entry remains a bug to be fixed, never a rewarded violation.
