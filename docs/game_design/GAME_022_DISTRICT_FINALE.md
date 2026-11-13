# GAME-022 — District Finale, Civic Scorecard, and Free Roam

**Date:** 2026-11-07  
**Branch:** `fix/regression-nov05`  
**Status:** Code and focused tests committed; Godot 4.7.2 runtime/playthrough verification pending.

## Player experience

Finishing **Market Clean-Up Chain** completes the first Civic Chaos campaign, provided the authoritative civic history also confirms the footpath tutorial, wrong-way traffic rescue, and illegal-parking recovery.

A full-screen results overlay presents:

- The completed tutorial and **three linked civic story incidents**, including each mission title, completed status and awarded mission points.
- Real **Safety / Efficiency / Trust / Cooperation** scores (0–1000), rendered with numeric labels and bars.
- **Reputation**, the truncated average of the four measured civic dimensions, with one of four district standings:
  - 600+ Outstanding
  - 540–599 Strong progress
  - 500–539 A better beginning
  - Below 500 Room to improve
- Total mission points (not awarded again by opening the screen).
- A closing story acknowledgement: the traffic jam was cleared, the footpath reopened, and the market cleaned.

**Continue in Free Roam** dismisses the finale, unpauses gameplay, resumes keyboard/touch control, and switches the mission guide and HUD to Free Roam. The district's vehicles, pedestrians, street props and civic world remain live. There is no gameplay transition to a duplicate scene.

Players can reopen the district scorecard with **F2** on PC or the persistent **DISTRICT RESULTS** on-screen button on PC/touch devices. **Replay Story** opens an explicit confirmation and restarts from the tutorial. Restart does not erase the prior disk checkpoint immediately; saving after starting over will overwrite its latest primary generation.

The scorecard uses the existing CanvasLayer GUI and keyboard-accessible buttons. Its contents scroll to fit smaller viewports.

## Security and source of truth

`CivicDistrictCampaign.can_unlock(...)` is an offline, non-mutating prerequisite:

1. All four actual mission-specific snapshots report a completed state.
2. The authoritative `CivicMissionManager` contains the four expected mission IDs with **COMPLETED** states, every objective at its required target, and each reward already claimed.
3. The `CivicIncidentManager` contains four distinct incident IDs with the correct types, each physically **RESOLVED**.
4. The `CivicCityMetrics` ledger contains the four mission-specific, idempotent outcome IDs, and all four measured dimensions are bounded.
5. The scorecard derives reputation and mission points from those ledgers. Viewing or reopening is strictly read-only: no mission event, score change, reward claim or incident transition occurs.

This does **not** claim cryptographic anti-cheat protection for an offline player-controlled save; GAME-018's checksum is for corruption detection and continuity.

## Persistence and restart

GAME-022 extends the existing GAME-018 verified save v2 **without changing its root format**. When the cleanup mission is finished, F5 adds:

```json
"campaign_checkpoint": {
  "schema_version": 1,
  "free_roam_unlocked": true,
  "finale_acknowledged": false
}
```

After **Continue in Free Roam**, `finale_acknowledged` becomes `true` and an autosave is attempted. The first completion also attempts to save *before* opening the paused ending. If the background world is unsafe for checkpointing, the unlock stays valid **in memory** and F5 can be retried; persistence is not falsely promised when a file write failed.

F9 rejects a campaign flag unless the same verified save generation includes a finished cleanup and valid authoritative campaign history. If an older GAME-021 checkpoint has all four completed missions but **no** `campaign_checkpoint`, the unlock is derived from the manager history and the finale is shown as unacknowledged. If a saved finale has already been acknowledged, loading returns directly to Free Roam and the results remain available via F2/on-screen button.

Existing GAME-017–020 restore behavior remains in place. A successful outer load does not claim that the deferred player-position collision check has passed; that is a separate open acceptance gate.

## Code additions / changes

- `scripts/civic/district_campaign.gd`: immutable unlock gate, cross-mission and incident consistency, district standings and scorecard model, versioned acknowledgement checkpoint.
- `scripts/ui/district_finale.gd`: scrollable results, accessible buttons, persistent review action, confirmation before replay.
- `scripts/core/main.gd`: Free Roam event wiring, first-completion autosave, F2 input, F5/F9 preflight/restore, HUD/guide progression, replay/continue handling.
- `tests/support/campaign_fixture.gd`: four completed manager scenarios created via the real mission/incident/metric APIs.
- `tests/district_campaign_unlock_test.gd`: authentic totals, re-open idempotence, unfinished/corrupt manager states, missing rewards and metric events, unknown schema and nonboolean flags.
- `tests/district_finale_ui_test.gd`: Free Roam gating, visible score labels/bars, continue, review, confirmed replay and dismissal.
- `tests/district_finale_checkpoint_test.gd`: disk JSON acknowledgement persistence, legacy completed checkpoint derived unlock, backup recovery and tamper rejection.
- `tools/run_regression.py`: three new test files registered; existing engine-error detection and replay rules remain unchanged.

## Local Windows acceptance

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }

$tests = @(
    "district_campaign_unlock_test.gd",
    "district_finale_ui_test.gd",
    "district_finale_checkpoint_test.gd",
    "market_cleanup_live_test.gd",
    "market_cleanup_checkpoint_test.gd",
    "wrong_way_checkpoint_test.gd",
    "parking_checkpoint_test.gd",
    "multi_incident_checkpoint_test.gd",
    "save_resilience_test.gd"
)
foreach ($test in $tests) {
    & $godot --headless --path . --script "res://tests/$test"
    if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
}

python tools/run_regression.py --godot $godot --timeout 120 --report build/game-022-finale-report.json
Write-Host "Exit code: $LASTEXITCODE"
```

New expected success markers **not yet observed**:
- `CIVIC_CHAOS_DISTRICT_CAMPAIGN_UNLOCK_PASS`
- `CIVIC_CHAOS_DISTRICT_FINALE_UI_PASS`
- `CIVIC_CHAOS_DISTRICT_FINALE_CHECKPOINT_PASS`

### Manual gameplay acceptance

1. Play through tutorial → wrong-way recovery → footpath relocation → market cleanup.
2. Complete all three wrappers and the sanitation worker response. Results should open automatically only after all four civic milestones are resolved.
3. Verify all four scores against the HUD's real city metrics and verify mission points sum to the actual claimed reward ledger.
4. Choose Continue in Free Roam. Confirm movement resumes and background city traffic/pedestrians continue.
5. Reopen the scorecard via F2 and via the on-screen results button; confirm score and reward history is unchanged.
6. Save after acknowledging the finale, restart and F9. The game should resume Free Roam without showing a new award.
7. Check an older completed GAME-021 save without a `campaign_checkpoint`: it should derive unlock from the full civic history and offer the finale.
8. Test a forged `campaign_checkpoint` against a still-active cleanup mission: F9 must reject it.
9. Confirm Replay Story asks first and returns to the original tutorial without silently deleting the previous file.

## Remaining and known limitations

- No runtime Godot compiler/tests or Windows/Android device playback was available to the editing environment. All three focused test scripts were authored and registered, **not executed**.
- Previous GAME-014 through GAME-021 runtime regression acceptance, background-traffic restore and deferred player placement remain unresolved until the local Godot 4.7.2 gate passes.
- The scorecard is entirely built with Godot Controls; animations, sound effects, polished art and celebratory particle effects are future visual tasks.
- Free Roam retains the already simulated district; the separate emerging-incident event director is not yet connected, so roaming is exploratory, not an infinite mission generator.
- A replay restarts the current scene rather than creating a second save slot. Multiple replay profiles/new save slots remain out of scope.
- UI is sized for smaller viewports, but Android touch interaction and safe-area handling need a real device check.
- The original project backlog used GAME-021 for *emergent event cascades*. The continuation milestones now name market cleanup GAME-021 and the finale GAME-022; the older planned event-cascade line remains independently pending.

**CI policy:** Both GitHub workflows are manual-only; no workflow runs were dispatched. Do not run Actions until the user authorizes the final release gate. The local report name is unique and does not touch the locally modified `build/regression-report.json`.
