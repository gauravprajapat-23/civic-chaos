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
- Requires 13 focused tests to pass with their exact markers.
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

## Local validation (Windows PowerShell)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch fix/aud-001-game024-gate-hardening
git pull --ff-only origin fix/aud-001-game024-gate-hardening

# Pure Python QA infrastructure checks; no Godot required for this step.
python -m unittest discover -s tests -p "test_regression_runner.py" -v
if ($LASTEXITCODE -ne 0) { throw "Regression runner unit tests failed" }

# Godot 4.7.2: import + 9 focused fixtures + 93+ full regressions.
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

`AUD-001` is **not completed** by these code commits alone. It is completed only after a verified clean commit passes all runner tests, Godot 4.7.2 import, 9 focused tests, full suite and negative-path check. Follow-on work should address the first real failing engine log instead of beginning an unrelated feature.
