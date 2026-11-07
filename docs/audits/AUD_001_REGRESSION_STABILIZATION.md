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
- Requires 9 focused tests to pass with their exact markers.
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

## Local validation (Windows PowerShell)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
git switch fix/aud-001-game024-gate-hardening
git pull --ff-only origin fix/aud-001-game024-gate-hardening

# Pure Python QA infrastructure checks; no Godot required for this step.
python -m unittest discover -s tests -p "test_regression_runner.py" -v
if ($LASTEXITCODE -ne 0) { throw "Regression runner unit tests failed" }

# Godot 4.7.2: import + 9 focused fixtures + 90+ full regressions.
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
