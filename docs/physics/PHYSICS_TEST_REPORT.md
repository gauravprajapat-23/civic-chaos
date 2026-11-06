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
| Player cannot walk horizontally through NPC | `tests/player_pedestrian_contact_test.gd` (Phase 2) | NOT RUN |
| Player falls through NPC roof to world floor | `tests/player_pedestrian_contact_test.gd` (Phase 2) | NOT RUN |
| NPC separation/crossing | `tests/pedestrian_collision_test.gd` | RETEST REQUIRED |
| Vehicle stops for player | `tests/vehicle_obstacle_test.gd` | RETEST REQUIRED |
| Road/surface alignment | `tests/surface_player_test.gd` | RETEST REQUIRED |
| Isolated sim throughput | `tests/traffic_spawner_test.gd` | RETEST REQUIRED |
| Gameplay car-v-car and spawn clearance | Add actual-frame tests | NOT IMPLEMENTED |
| Frame-rate stability 30/60/120 FPS | Manual controlled frames + profiling | NOT RUN |

## Reporting rule
Log engine version, platform, branch commit, exact command, all failed assertions, reproducible setup, and any gameplay evidence. No GitHub Actions; no unobserved PASS claims.
