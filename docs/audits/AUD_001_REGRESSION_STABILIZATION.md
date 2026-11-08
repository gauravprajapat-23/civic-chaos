# AUD-001 — GAME-024 regression stabilization: first fix batch

Date: 2026-11-07  
Working branch: `fix/aud-001-game024-gate-hardening`  
Base: `feat/game-024-dynamic-free-roam` (do **not** merge the unverified GAME-025 preview here)

## Status

**Source fixes committed; Godot 4.7.2 acceptance not yet executed.** No GitHub Actions were triggered. This fixes two QA-infrastructure problems and corrects an unsafe test timing pattern. This does **not** prove the gameplay is now passing.

## Findings and changes

### AUD-001-R01 — Test inventory could silently shrink (P0)

Previously `tools/run_regression.py` silently discarded registered tests whose files were missing, and would still report success if the reduced suite passed. It now:

- Deduplicates registered fixtures but **refuses** missing names before Godot is launched.
- Records `expected_test_count`, `missing_tests`, and all per-test results in the JSON report.
- Refuses a partially run suite.
- Requires the expected per-test PASS marker, not any arbitrary `CIVIC_CHAOS_..._PASS` marker in stdout.
- Preserves exact legacy marker aliases for the 17 older fixture names that print a historical PASS marker.

`tests/test_regression_runner.py` adds executable Python checks for marker spoofing/mismatches, alias isolation, missing fixtures, nonzero exits and Godot script errors.

### AUD-001-R02 — Acceptance script could hang or accept incomplete reports (P0)

`tools/verify_game024.ps1` now:

- Runs each focused Godot invocation with a bounded timeout and separate stdout/stderr files.
- Checks for the exact Godot version, expected branch, 40-character commit SHA and clean tracked worktree.
- Accepts an explicit `-ExpectedBranch` for this reviewed fix branch; it never silently treats that as the main GAME-024 branch.
- Requires 19 focused tests to pass with their exact markers.
- Requires the full regression report to contain **at least 90 completed tests**, no missing fixtures, no failed cases, passing import and passing deliberate negative-path check.
- Records full test inventory size in the acceptance report and rejects a changed source revision while testing.

### AUD-001-R03 — Physics-space queries called from tight nonphysics loops (P0)

Five GAME-023/024 Free Roam fixtures invoked `_physics_process(0.25)` from deferred callbacks without advancing real physics frames. GAME-024's spawn logic queries `World3D.direct_space_state`, so the fixture could probe a locked physics world. Their loops now await Godot's `physics_frame` signal before each accelerated event tick and explicitly disable automatic processing to prevent double-advance. The restart helper is awaited by its caller.

Changed tests:

- `tests/free_roam_live_events_test.gd`
- `tests/free_roam_dynamic_locations_test.gd`
- `tests/free_roam_expiry_test.gd`
- `tests/free_roam_legacy_migration_test.gd`
- `tests/free_roam_event_restart_test.gd`

These are targeted **test-time changes**, not claims that the physical placement logic has been verified.

## Follow-on stabilization batch — test completeness and clock isolation

### AUD-001-R04 — Automatic fixture discovery and actionable failure artifacts

The hardened regression runner now includes every `tests/*_test.gd` file on disk in addition to the mandatory workflow/manual contract. A new fixture is therefore never accidentally skipped simply because the legacy registration tuple was not edited. A missing mandatory fixture still fails the inventory.

Each run now writes `build/regression-logs/<test>.log`, embeds failure reasons and the final 4,000 characters of failing output in the JSON report, records deterministic replay output, and writes partial JSON after every test. A crash mid-suite can no longer leave no evidence of the tests already reached. New Python unittest cases check automatic fixture discovery, missing required names and engine-error rejection.

### AUD-001-R05 — Isolate clocks during real-physics fixture stepping

The five accelerated Free Roam tests now also disable automatic processing on the tutorial `CivicGameplaySession`. Without this, each awaited physics frame advances the tutorial incident clock independently while Free Roam is manually advanced by 0.25 logical seconds, creating false out-of-order incident transitions. The actual `CivicFreeRoamEvents` uses its own deliberately stepped logical time in these fixtures, matching the pre-existing test intent while executing physics-space queries on valid Godot frames.

`free_roam_npc_reactions_test.gd` now runs its speech expiry on actual physics frames with the pedestrian controller's automatic processing disabled, avoiding double-processing or physics-space queries from the deferred test callback.

### AUD-001-R06 — Acceptance must match complete source, not only tracked files

The verification gate now rejects **untracked new source and test files** as well as modified tracked files. Generated `build/` artifacts are excluded from that status check. A fresh attempt resets the acceptance JSON to `blocked` before launching Godot so an interrupted rerun cannot leave a stale `passed` report visible.

## Follow-on stabilization batch — reliable negative-path acceptance (source only)

### AUD-001-R07 — Deliberate failure is not a timeout or crash

The strict Python runner previously treated **any** nonzero Godot exit with the intentional-failure marker as a successful negative-path test. If Godot printed the marker and then hung, the timeout returned `-1` and could be accepted as success. It now requires:

- Exact **exit code 1** from the forced-failure smoke test, without timeout.
- The `CIVIC_CHAOS_INTENTIONAL_FAILURE` marker in that run's output.
- Recorded `negative_path_exit_code` and `negative_path_timed_out` report fields.
- Separate `timed_out` and `nonzero_exit` failure reasons for ordinary tests.

Godot subprocess output is decoded as UTF-8 with replacement instead of the system-specific Windows locale, protecting the local runner from Unicode decoding crashes. The Python unittest suite includes timeout/crash refusal, UTF-8 decoder options, and explicit timeout provenance.

### AUD-001-R08 — One-command acceptance runs the Python self-tests

`tools/verify_game024.ps1` now executes `python -m unittest discover -s tests -p test_regression_runner.py -v` itself and requires at least **nine** passing checks before Godot import. It writes `build/game-024-verification-logs/python-runner-tests.log` and records `python_runner_checks_passed` plus `python_runner_test_count` in the gate JSON. These checks are safe to run locally, without triggering Actions.

**Verification remains OPEN.** Source code was updated, but no Python or Godot test was executed in this authoring environment. Passing tests must be confirmed on the exact Windows checkout and SHA.

## AUD-001-R09 — Static Godot resource reference preflight (next work batch)

The engine failures called out in draft PR #48 include a vehicle scene load and NPC personality preload. Source-only checks cannot prove Godot import is healthy, but they can identify missing **literal** dependencies and duplicated global classes before launching the editor.

Added:

- `tools/preflight_godot_sources.py` scans GDScript, `.tscn`, `.tres`, `.gdshader` and project configuration for literal `preload`, `load`, `ResourceLoader.load/exists`, scene `path="res://..."` and `run/main_scene` references.
- It rejects missing literal source/scene resources, unsafe `res://../` paths, duplicate `class_name` names and missing project configuration. Dynamic runtime-computed asset paths and GDScript syntax are **outside** its scope.
- The scanner ignores full-line commented import examples and excludes generated `.godot/`, `build/` and Git internals.
- Its standalone JSON inventory at `build/game-024-source-preflight.json` includes `passed`, files scanned, static resource reference count, global class count and detailed issues.
- `tests/test_source_preflight.py` supplies seven tests for valid dependencies, missing resources, duplicate classes, dynamic paths, invalid relative paths, commented examples and missing project files.
- `tools/verify_game024.ps1` runs **at least 18 Python tests** across `test_*.py`, then runs the source preflight before Godot import; any failed Python preflight blocks acceptance and records diagnostics.

**Evidence:** The seven source-preflight unit tests passed in an isolated local Python 3.13 fixture, and the committed source/test blob hashes matched those tested. This does **not** establish that the entire live GitHub repository passed static preflight or that Godot 4.7.2 successfully imported it. The latest branch's full Python suite, Godot import, 90+ GDScript regression tests and manual gameplay still require the developer's Windows checkout.

Fast local diagnostic (no Actions):

```powershell
python -m unittest discover -s tests -p "test_*.py" -v
if ($LASTEXITCODE -ne 0) { throw "Python QA checks failed" }
python tools/preflight_godot_sources.py --report build/game-024-source-preflight.json
if ($LASTEXITCODE -ne 0) {
    Get-Content build/game-024-source-preflight.json
    throw "Godot literal source references are broken"
}
```

## AUD-001-R10 — Isolated vehicle scene and NPC preload regressions

The November 5 regression ticket (#48) names two unresolved startup blockers: a vehicle `.tscn` load/parse failure and an NPC personality preload failure. Without the actual Godot log, neither root cause is confirmed. This batch **does not invent a diagnosis or change vehicle behavior**; it adds independently reproducible tests with explicit failure reasons.

- `tests/vehicle_scene_contract_test.gd` dynamically loads the real `vehicle_agent.tscn` and checks it is a `PackedScene`, its instantiated root is `CivicVehicleAgent`, the expected four wheel and body children exist, the vehicle is on collision layer 4 with a valid box, and a legal lane route can configure. If loading fails, the assertion identifies the scene contract rather than crashing the test with a null child.
- `tests/npc_personality_contract_test.gd` explicitly loads `npc_personality.gd`, checks the preloaded class factory, seeded replay, serialized roundtrip, distinct mutable resource instances, and trait-bounds validation.
- `tests/npc_utility_test.gd` no longer relies on `assert()` calls, which may be disabled in some Godot builds; every failed behavioral check now pushes an engine error and exits nonzero.
- `tests/vehicle_obstacle_test.gd` and `tests/vehicle_world_obstacle_test.gd` now fail with targeted diagnostics when the packed vehicle scene cannot instantiate.
- Both new tests are **mandatory** in the local full regression inventory and run early as focused acceptance checks, raising the required minimum from **90 to 92 Godot fixtures**.

The engine test is still **NOT RUN** in this environment. Once Godot 4.7.2 is available on the Windows checkout, examine `build/game-024-verification-logs/vehicle_scene_contract_test.gd.log`, `npc_personality_contract_test.gd.log`, and the script import log, then fix the first proven engine root cause. No Actions are to be used.

## AUD-001-R11 — Optional vehicle feedback must not block traffic

The vehicle root had a **hard GDScript type dependency** (`var feedback: CivicAgentFeedback`) even though `_ready()` tried to load `agent_feedback.gd` dynamically as an optional presentation component. If the presentation class is unavailable or its global class registration fails, the driving script may fail to parse before the soft fallback can run. This source-level mismatch is confirmed; whether it caused the previously reported scene parse failure remains unverified.

- `scripts/traffic/vehicle_agent.gd` now stores the cue node as a generic `Node3D`; it checks `ResourceLoader.exists`, validates the loaded script and cue method before attaching, and uses a guarded dynamic call when the vehicle advances. It does **not** change lane motion, signals, collision policy, or score logic.
- `feedback_enabled` and `feedback_script_path` support an explicit cue-off or missing-script scenario in tests. The normal scene uses the original default cue script and appearance.
- `tests/vehicle_feedback_optional_test.gd` uses the **real physical car scene** to verify travel in three cases: normal cue script, disabled cues, and nonexistent optional cue script. Normal cues must still report a moving state. A missing optional cue must not prevent the car from being configured or advancing.
- This new test is mandatory, increases the minimum suite from **92 to 93** fixtures, and raises the focused gate from **12 to 13**.
- No actual Godot 4.7.2 import or runtime test has been executed in this environment. The observed type dependency is fixed in source, but the earlier startup error is **not declared resolved** without engine evidence.

## AUD-001-R12 — Fix physical traffic tests that query locked physics space

Source inspection found three traffic fixtures invoking the physical vehicle spawner from long deferred-callback loops rather than from actual Godot physics ticks. `CivicTrafficSpawner.try_spawn()` creates a real `VehicleAgent` and calls `footprint_blocked_at()`; the GAME-020 traffic restore path also invokes vehicle footprint queries when staging a replacement generation. These operations use `World3D.direct_space_state`, which is not safe to access from arbitrary nonphysics callbacks.

The following **test-only** fixes now wait for `physics_frame` before stepping the traffic sim or performing a physical restore:

- `tests/traffic_spawner_test.gd`: 1,600 fixed ticks and physical car-spawn checks are scheduled on physics frames rather than in one synchronous loop. It retains the existing 20-spawn and throughput acceptance assertions.
- `tests/city_traffic_test.gd`: perimeter vehicle spawn attempts run on physics frames before checking real scene collision.
- `tests/traffic_transaction_stress_test.gd`: preflight traffic spawning and repeated PREPARE/ABORT/COMMIT snapshots execute after physics-frame boundaries, so `footprint_blocked_at()` cannot be called from the original deferred test loop.
- `tests/traffic_budget_test.gd`: replaces all bare `assert()` calls with descriptive `push_error()` and nonzero exits, guarding against disabled runtime assertions.

This keeps live traffic, checkpoint schema, spawn policies and vehicle collision settings unchanged. The purpose is to remove test-harness artifacts and expose genuine traffic failures. The then-current 93-fixture GAME-024 regression baseline was unchanged by the fixture-only edits.

**Important:** These fixes have not been run in Godot 4.7.2 here. They should be followed by targeted `traffic_spawner_test.gd`, `city_traffic_test.gd`, `traffic_transaction_stress_test.gd`, and `traffic_budget_test.gd` executions as well as the full local acceptance script. Any real physics lock error or throughput failure in that run must be investigated from its log, not presumed fixed.

## AUD-001-R13 — Reject impossible restored traffic generations

**Confirmed source-level bug:** `CivicTrafficSpawner.can_restore()` previously checked `completed_total <= spawned_total` and `cars.size() <= spawned_total` separately, but accepted a checkpoint whose completed and active cars **together** exceeded all spawned vehicles. It also allowed a checkpoint to restore an **active** car with its current route index at the end of its final lane. Such a car would have zero remaining travel, so `advance_fixed()` could never reach the `_travel()` branch that completes and removes it, leaving a permanent ghost vehicle and reducing throughput.

Source fixes in `scripts/traffic/traffic_spawner.gd`:

- Reject checkpoint generation if `completed_total + cars.size() > spawned_total`.
- Reject a saved active car whose final-route `lane_distance` is at/past the final lane's endpoint; a legitimate car merely *approaching* the endpoint remains valid.
- Reject nonfinite fixed-step durations and invalid zero/negative spawn intervals before advancing tick counters or using modulo.
- Preserve the existing checkpoint format and accepted real gameplay snapshots; invalid restores are refused **before** any staged collision actors are allocated.

`tests/traffic_checkpoint_invariants_test.gd` is a new pure validation fixture, covering a valid single active vehicle, forged active+completed accounting, overclaimed completions, terminal ghost car, past-end values, near-end valid car, unchanged live state after rejected validation, infinite delta and zero spawn interval. The marker is `CIVIC_CHAOS_TRAFFIC_CHECKPOINT_INVARIANTS_PASS`.

The test is registered with the strict runner and focused gate, raising **mandatory Godot fixtures to 94** and **focused checks to 14**. No Godot binary was available in this authoring environment; source-level implementation is committed, but **runtime verification remains pending**.

## AUD-001-R14 — Failed traffic reconfiguration must not destroy live state

**Confirmed source defect:** `CivicTrafficSpawner.configure()` previously aborted any staged checkpoint, queued the existing fleet for deletion, cleared vehicle-delay tracking, and changed the current road graph/mode **before** checking whether an expanded-city graph had even one eligible perimeter entry lane. When this late check failed, `configure()` returned `false` but the previous traffic generation was already lost.

Source fix in `scripts/traffic/traffic_spawner.gd`:

- Evaluate graph validity, spawn interval/agent limit/clearance and expanded-city entrance eligibility **before** calling `abort_restore()`, deleting vehicles, or changing counters, seed, road graph or mode.
- Build proposed city entries in a local typed array and assign it only once validation succeeds.
- Preserve the existing semantic that a **successful** configuration replaces the previous fleet and cancels a prepared checkpoint, resetting counters and RNG to the newly requested seed.
- The network, save schema and gameplay feature flags are unchanged. The change affects normal traffic reconfiguration as well as the isolated test harness.

New `tests/traffic_reconfigure_atomicity_test.gd` checks a rejected expanded-city graph **both with an in-progress restore and with an active physical vehicle**, along with rejected zero spawn interval and nonfinite clearance. It asserts unchanged actor identity, fleet inventory, road graph, RNG state, counters and restore transaction after failure. It also checks that a legitimate new configuration resets traffic, retires the old vehicle and invalidates a prepared restore.

Registered in the strict full regression and GAME-024 focused gate: **95 mandatory Godot tests / 15 focused tests**. Status: code committed, **Godot 4.7.2 runtime not executed here**.

## AUD-001-R15 — Reliable Windows full-suite logs and commit-bound evidence

**Confirmed QA-path risk:** `tools/verify_game024.ps1` previously captured `python tools/run_regression.py ... 2>&1 | Out-String` while setting `$ErrorActionPreference = "Stop"`. Native stderr emitted by a failing Godot/Python fixture can be surfaced as a terminating PowerShell error on Windows PowerShell 5.1 before the combined `full-regression.log` is saved. The focused tests already used redirected subprocess files; the full 95-test suite did not.

- The PowerShell gate now launches the full Python runner through `Run-Local` using redirected stdout/stderr files and a separate bounded **suite deadline**, in addition to the existing per-Godot-fixture timeout. The gate records full-run exit code and timeout in `game-024-verification.json`, and retains the full runner log on failure.
- On a Windows timeout, the script attempts to terminate the whole child process tree with `taskkill.exe /PID ... /T /F` before falling back to direct process termination.
- The Python runner now obtains the **actual `git rev-parse HEAD`** (40 hexadecimal digits), records it as `source_commit` in all JSON reports, and fails closed if no valid SHA is available. New Python self-tests cover the real 40-digit SHA, invalid revision text, nonzero Git exit, missing Git executable and timeout.
- The PowerShell acceptance gate rejects a full regression report whose `source_commit` does not equal the exact checked-out `$gate.commit`; it records the report SHA for troubleshooting. This blocks reusing a passing report from another revision.
- The mandatory Python self-test minimum is now **20**; the GAME-024 Godot inventory remains **95** and focused test list remains **15**.

**Evidence boundary:** These are committed code-level improvements, not a completed Windows execution. PowerShell and Godot binaries are unavailable in the authoring environment; the 20 Python tests and Godot regression gate must still be executed on the exact Git checkout before this PR can be merged.

## AUD-001-R16 — Reject signed but malformed nested checkpoints before mission restore

**Source-level crash risk:** `scripts/core/main.gd` reads `saved["campaign_checkpoint"].get("finale_acknowledged", false)` when `free_roam_checkpoint` is present, before checking that `campaign_checkpoint` is a `Dictionary`. Other optional checkpoint records are also later dereferenced with `.get()`. The v2 checksum in `CivicSaveRepository` protects the file's *integrity*, but does not validate every optional gameplay record's *type*. A correctly checksummed but malformed save could therefore throw a Godot runtime error during loading instead of failing cleanly.

- Added `static func checkpoint_record_types_valid(saved: Dictionary) -> bool` in `scripts/core/main.gd`. It rejects any present optional `civic_session`, `wrong_way_checkpoint`, `parking_checkpoint`, `cleanup_checkpoint`, `campaign_checkpoint`, `free_roam_checkpoint` or `world_checkpoint` that is not a Dictionary.
- This preflight runs immediately after player eligibility checking, **before** any stage logic dereferences nested records or changes world actors. A player-only legacy save with none of those records remains eligible.
- Added `tests/checkpoint_record_shapes_test.gd`: checks all seven optional record names with invalid null/boolean/integer/string/array values, accepts dictionary-valued entries and legacy absence, and verifies that a file **signed by the real SaveRepo writer** with a malformed campaign field is rejected by gameplay shape validation.
- The new test is mandatory and focused: **96 Godot regression fixtures / 16 focused checks**. This does not bypass the existing deeper mission/world validators, which continue to check the contents of appropriately typed dictionaries.

**Execution status:** Committed source and test coverage; Godot 4.7.2 and Windows PowerShell are absent from this environment, so runtime acceptance remains **PENDING**. The PR stays draft and GAME-025 remains disabled.

## AUD-001-R17 — F9/recovery loads run on the physics tick with an exact snapshot

**Confirmed source-level timing risk:** F9 in `scripts/core/main.gd::_unhandled_key_input()` and the mission-guide reload button invoked `_load_gameplay_checkpoint()` synchronously from input/UI callbacks. The restore path prepares background cars and physical pedestrians, which perform `PhysicsDirectSpaceState3D` overlap/ray checks. Godot collision-space operations must be carried out on a safe physics tick; previously, input delivery had no such guarantee.

- Added `scripts/core/checkpoint_load_queue.gd` as a one-request deep-copy queue. It captures the **verified document selected when the player presses F9**, rather than rereading the file later and accidentally choosing a newer generation written by an intervening F5.
- Both F9 and the mission-guide `reload_checkpoint` action now call `_queue_gameplay_checkpoint_load()`, which records the chosen `SaveRepo.read_save_detail()` and prevents duplicate pending requests. Neither input callback directly stages world colliders.
- Added `_physics_process()` in the main scene script: it consumes exactly one queued document then calls `_load_gameplay_checkpoint(selected)` within Godot's physics frame. Existing direct internal invocation remains supported when no selected snapshot is supplied.
- Added `tests/checkpoint_load_queue_test.gd`: generates a real checksum-valid save A, queues it, mutates the original Dictionary, writes save B, refuses a second F9, then asserts consumption still yields A and cannot repeat. It next selects B, and verifies pending cancellation leaves no stale data.
- This test is registered both in the strict runner and focused gate, bringing the required inventory to **97 Godot fixtures / 17 focused checks**. The Python harness minimum remains 20.

**Runtime status:** Source changes have been committed. Actual Godot 4.7.2 input-to-physics integration, scene import and full regressions have not been executed in this environment; these remain required before AUD-001 acceptance. This is not an engine-verified fix.

## AUD-001-R18 — Reject orphaned mission/world records in player-only saves

**Confirmed source-level integrity gap:** `main.gd::_load_gameplay_checkpoint()` treated any document without `civic_session` as a legacy player-only save and returned early after player restore. That path silently ignored other present fields such as `campaign_checkpoint`, `wrong_way_checkpoint`, `free_roam_checkpoint` or `world_checkpoint`. Even if all their values were dictionaries and the file was correctly signed, those records lacked a parent civic ledger and could never be validated against mission progress or physical actors.

- New `static func checkpoint_envelope_valid(saved)` in `scripts/core/main.gd` first applies existing nested type checks, then rejects **any** mission, campaign, Free Roam or world record found without its required `civic_session` parent.
- `_load_gameplay_checkpoint()` invokes this preflight **before** taking the legacy early return, staging mission actors, or touching saved player position.
- Legitimate historical saves with only the `player` record still pass. Saves containing both a properly typed `civic_session` and `world_checkpoint` remain eligible for deeper stage-specific checks; those checks are not bypassed or weakened.
- New `tests/checkpoint_orphaned_records_test.gd` writes **real checksum-valid v2 JSON documents** using `CivicSaveRepository`, tests all six possible orphaned record names, verifies that all remain readable with valid field types yet fail the game envelope, and confirms properly parented records are eligible. Wrongly typed world records remain rejected.
- The test is mandatory in the strict runner and focused acceptance gate: **98 total Godot fixtures / 18 focused checks**, with 20 Python QA self-tests unchanged.

**Execution status:** Source changes have been committed to the stabilization branch. No Godot 4.7.2 binary or Windows PowerShell is available in this environment; full runtime verification and actual playable campaign acceptance are still outstanding. PR #49 must remain draft.

## AUD-001-R19 — Player placement must be part of checkpoint acceptance

**Confirmed source-level integrity gap:** The full civic/world loader in `main.gd` previously committed the restored traffic and pedestrian world, then called `CivicGameLifecycle.load_player_snapshot()`. That API only queued player placement for the *next* physics tick, returning `true` even if the saved position later failed ground or collision checks. Consequently the game could announce a successful complete checkpoint while the player stayed behind or fell back to spawn, out of sync with newly restored mission actors.

- Added `CivicPlayerController.restore_now_safe(requested, yaw)`: execute the existing world-floor, wall/car/NPC overlap checks and actual placement **synchronously on a physics tick**, return `false` without moving or scheduling a delayed teleport if the candidate is unsafe.
- Added `CivicGameLifecycle.restore_player_snapshot_now(player, data)`, keeping `load_player_snapshot()` unchanged for existing player-only saves and standalone recovery tests.
- Updated the full-campaign restoration branch in `main.gd` to call the immediate validated method **after** staging incoming actors but **before** accepting the checkpoint. A failed collision/ground check now enters the existing civic and background-world rollback branch, rather than silently committing a mismatched player/world state.
- New mandatory and focused `tests/player_checkpoint_atomicity_test.gd` creates a real player, ground collider and blocking building; it tests successful physical placement and yaw, refusal of blocked/out-of-world saves without position change or delayed teleport, and preservation of the legacy deferred player-only API.
- Local acceptance inventory: **99 Godot fixtures and 19 focused tests**, with 20 Python QA checks.

**Important:** Actual success/rollback behavior still needs verification with Godot 4.7.2 in a full campaign scene. This source-level fix was committed without running the engine; PR #49 stays draft and unmerged.

## Local validation (Windows PowerShell)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch fix/aud-001-game024-gate-hardening
git pull --ff-only origin fix/aud-001-game024-gate-hardening

# Pure Python QA infrastructure checks; no Godot required for this step.
python -m unittest discover -s tests -p "test_*.py" -v
if ($LASTEXITCODE -ne 0) { throw "Regression runner unit tests failed" }

# Godot 4.7.2: import + 19 focused fixtures + 99+ full regressions.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\verify_game024.ps1 `
  -ExpectedBranch "fix/aud-001-game024-gate-hardening" -Timeout 120

if ($LASTEXITCODE -ne 0) {
  Get-Content .\build\game-024-verification.json
  throw "AUD-001 engine verification FAILED. Investigate the named test and its log."
}

Get-Content .\build\game-024-verification.json
```

Generated reports and logs:

- `build/game-024-verification.json` — source-bound acceptance gate.
- `build/game-024-regression.json` — per-test identity, exit, runtime and marker.
- `build/game-024-verification-logs/` — focused stdout/stderr and failure logs.
- `build/regression-logs/` — full per-test logs, replay output, and the expected negative-path diagnostic.

## Remaining blockers

1. Run the above tests on the actual Windows Godot 4.7.2 executable. **No current engine results have been supplied.** A committed older `build/regression-report.json` with 36 historical passes is not evidence for this branch.
2. Investigate any import/parser failure and any remaining physics/traffic throughput hangs from open draft PR #48 with exact engine output; do not guess or close the PR from source alone.
3. After the gate actually passes on the fix branch, do a manual full campaign walkthrough and free-roam E/USE, F5/F9 and Android touch checks. Compare accepted SHA before merging.
4. Keep GAME-025 daily routines **disabled** until GAME-024 is accepted on its exact tested source revision.
5. Do not dispatch/rerun GitHub Actions. Local tests are the source of acceptance evidence.

## Acceptance boundary

`AUD-001` is **not completed** by these code commits alone. It is completed only after a verified clean commit passes all runner tests, Godot 4.7.2 import, 19 focused tests, full suite and negative-path check. Follow-on work should address the first real failing engine log instead of beginning an unrelated feature.
