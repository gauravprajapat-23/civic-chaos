# Civic Chaos — Physics Test Report
Date: 2026-11-06 | Working branch: `fix/regression-nov05`

## What has actually been executed in this session
| Check | Result | Evidence |
|---|---|---|
| Read GitHub branch, scripts, scenes, tests and historical report | **DONE** | Source inspection via GitHub connector, initial head `75df6ee` |
| Local clone | **FAILED — network unavailable** | Container DNS cannot resolve github.com; repository read via connected GitHub instead |
| Godot 4.7.2 import | **NOT RUN** | Godot executable unavailable in this environment |
| Godot physics regression suite | **NOT RUN** | No engine executable |
| Windows gameplay | **NOT RUN** | No Windows Godot runtime |
| Android build/performance | **NOT RUN** | No Android device/toolchain |

## Historical evidence — do not substitute for current verification
- The checked-in `build/regression-report.json` contains **36 entries marked passed**, import exit code 0 and a passing negative-path check. It belongs to an earlier tested tree.
- The newer `docs/audits/ISSUE_REGISTER.md` records a user run of **38 of 41 passed**, with failures in `traffic_spawner_test.gd`, `pedestrian_collision_test.gd`, and `surface_player_test.gd`.
- Subsequent fixes were committed, but a clean rerun of that newer tree is **not established**.
- Do not mark the newest test status as PASS without executing it.

## Focused scenarios required
| Scenario | Test | Status |
|---|---|---|
| Player cannot walk horizontally through NPC | `tests/player_pedestrian_contact_test.gd` (commit `af04f32`) | NOT RUN |
| Player falls through NPC roof to world floor | `tests/player_pedestrian_contact_test.gd` (`af04f32`, updated `b442124`) | NOT RUN |
| Player blocks horizontally against car, then releases | `tests/player_vehicle_contact_test.gd` (`b442124`) | NOT RUN |
| Vehicle roof does not act as floor | `tests/player_vehicle_contact_test.gd` (`b442124`) | NOT RUN |
| Safe save/load and fall recovery | `tests/player_safe_restore_test.gd` (`9aa948d`) | NOT RUN |
| NPC separation/crossing | `tests/pedestrian_collision_test.gd` | RETEST REQUIRED |
| Vehicle stops for player | `tests/vehicle_obstacle_test.gd` | RETEST REQUIRED |
| Road/surface alignment | `tests/surface_player_test.gd` | RETEST REQUIRED |
| Isolated sim throughput | `tests/traffic_spawner_test.gd` | RETEST REQUIRED |
| Gameplay car-v-car and spawn clearance | Add actual-frame tests | NOT IMPLEMENTED |
| Frame-rate stability 30/60/120 FPS | Manual controlled frames + profiling | NOT RUN |

## Reporting rule
Log engine version, platform, branch commit, exact command, all failed assertions, reproducible setup, and any gameplay evidence. No GitHub Actions; no unobserved PASS claims.

## Implementation / unverified change log
- `af04f32` — player horizontal pedestrian cast and executable actual-frame regression registration.
- Follow-up test correction requires that player remains on the **approach side** of the pedestrian after walking, catches falling through or returning to spawn, and asserts floor contact. Exact verification pending.

## Phase 2 follow-up — current branch (2026-11-06)
- `b442124`: Player now uses world-only collision mask and horizontal swept actor collision for pedestrians and cars. Ground snap length 0.24. The parked-car test advances actual physics frames to verify approach, obstruction, release and non-walkable roof.
- `9aa948d`: Save loading no longer directly teleports player during input. The lifecycle queues a restore; player validates on the next physics tick and emits the final loaded/unsafe status. Validation checks ground normal, height proximity and capsule clearance against actors and world. Fall recovery checks safe spawn and deterministic nearby candidates.
- **Verification:** Source changes pushed, no Godot binary installed in this environment. Import, all three contact/recovery tests, full suite and Windows/Android gameplay are **NOT RUN**. Existing earlier regression JSON must not be relabeled as current results.

## Test fixture expansion at commit `1b7f908`
- `tests/player_safe_restore_test.gd` now tests blocked save points inside a building, a parked vehicle (layer 4), a pedestrian (layer 8), and outside the map, in addition to a valid restore and fall recovery. Uses an isolated `user://` test save file and removes it after completion.
- `scripts/core/game_lifecycle.gd` retains the production default path while supporting an optional test-only path.
- **Verification: NOT RUN** (engine unavailable); a committed test is not a passing test.

## Screenshot NPC-overlap regression (2026-11-06)
- Input evidence: screenshot of multiple pedestrian models intersecting near a road crossing.
- `f89584b` changed the movement candidate chooser, spawn clearance, sidestep and intermediate collision checks.
- `tests/pedestrian_collision_test.gd` now watches separation for 360 physics frames with a 0.72m floor (previously 120 frames / 0.64m).
- `tests/pedestrian_crowd_avoidance_test.gd` constructs a forced perpendicular approach and an opposing-direction approach, observing all pedestrian pairs each frame and asserting forward progress rather than permanent deadlock.
- `tools/run_regression.py` explicitly registers the new test. **Godot outcome = NOT RUN**. No GitHub Actions executed.

## Follow-up: screenshot of player/NPC overlapping at identical coordinates (2026-11-06)
- Changes committed on branch `fix/regression-nov05`: `404755a` remove hard actor collision and add player yielding/local soft depenetration; `27f32d9` move player spawn to safe sidewalk and add `tests/pedestrian_spawn_separation_test.gd`; `484caae` separate overlaps even when stopped at traffic lights; `28b9969` ignore ground surfaces in NPC obstacle tests; `224ebcc` add forced player+NPC same-position scenario.
- The previous player/NPC physical-blocking test was updated for the explicitly changed behavior: player no longer collides rigidly with pedestrians. Pedestrians should yield and recover; cars still detect them on sensing layer 8.
- Static repository changes were reviewed and pushed, but **Godot 4.7.2 import = NOT RUN, test suite = NOT RUN, actual screenshot recheck = NOT RUN**. No GitHub Actions manually run.
- Next validation: full local regression plus gameplay inspection around the screenshot crossing. If the new spawn test fails, retain the failure and fix the reported root cause rather than weakening its spacing checks.

## User-supplied failing 2026-11-06 regression
- Branch `927fc8f`, Godot `4.7.2.stable.official.ed1daf0bf`: successful import. All displayed tests PASS except `pedestrian_spawn_separation_test.gd`; error `overlapped NPCs failed to recover personal space`; runner exit 1.
- Corrective code pushed in `247cf80`: use a separate bounded actor-overlap escape check rather than applying normal path clearance to already embedded agents; set `sync_to_physics = false` for manually moved AnimatableBody3D walkers.
- Test now includes diagnostic coordinates and sync-mode contract. **Latest code NOT RUN** on Godot in the assistant environment. This section reports user-provided output only. No GitHub Actions triggered.
