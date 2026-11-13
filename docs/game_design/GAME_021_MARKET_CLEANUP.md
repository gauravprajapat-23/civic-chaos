# GAME-021 — Market Clean-Up Chain

**Date:** 2026-11-07  
**Branch:** `fix/regression-nov05`  
**Status:** Source implemented and committed; **Godot 4.7.2 import, gameplay and runtime tests not yet executed**.

## Goal and gameplay

After the player has completed the Footpath Blocked tutorial, Wrong Way, Wrong Day, and the real pedestrian recovery in Footpath First / Illegal Parking, **Market Clean-Up Chain** begins near Market Chowk.

The third story incident is a concrete offline civic activity, not an automatic score change:

1. Three small **visible, interactable litter objects** are placed near the north market walkway, at x≈12, z≈−31…−37.
2. Approach any wrapper and press **E / USE**. The existing incident card offers **Inspect Evidence**. A wrapper cannot be collected before inspection.
3. Choose **Collect wrapper**. The actual world object becomes invisible and untargetable, and the player carries **one** wrapper at a time.
4. Take the wrapper to the green market bin at x≈15, z≈−39 and choose **Place carried wrapper in bin**. Deposits increase the real bin fill counter and mission progress.
5. The bin holds exactly **two** wrappers. Trying to deposit a third while it is full is denied.
6. Approach the municipal sanitation helper at x≈10.5, z≈−41 and request service. This is only authorized after the bin actually fills. The existing validated `CivicInteractionService` handles the report and incident escalation.
7. Watch the helper **move in the physical world** to the bin at x≈13, z≈−39. The bin is emptied only after the helper reaches the actual destination. A second service request is rejected.
8. Deposit the final wrapper. The incident resolves only after **all three wrappers have been deposited and the sanitation worker has arrived**. The mission rewards 90 points once; city scores change by **Cooperation +25, Trust +15, Efficiency +10**.

The helper's in-world caption changes to acknowledge service completion, and finally thanks the player for cleaning the market. Other ambient pedestrian reactions and a litter-spawning event director are still future work.

### Implementation files

| File | Role |
|---|---|
| `scripts/civic/cleanup_target.gd` | Single reusable physical interaction actor with litter, bin, helper visuals; layer-16 E/USE target |
| `scripts/civic/market_cleanup_mission.gd` | 3-wrapper inventory, limited bin, worker movement, one-time incident and mission outcomes, guide, checkpoints |
| `scripts/core/main.gd` | Starts cleanup after parking recovery; hooks card, guide, save/load/restore and rollback |
| `scripts/ui/civic_incident_card.gd` | Existing button safely dispatches `collect_litter`, `deposit_litter` and `request_service`; original `report` remains unchanged |
| `scripts/civic/gameplay_session.gd` | Completed tutorial checkpoint remains valid after newer incident ticks |
| `scripts/civic/illegal_parking_mission.gd` | Completed parking checkpoint remains valid after newer cleanup incident ticks |
| `tools/run_regression.py` | Adds three cleanup tests and registers previously omitted `npc_utility_test.gd` |

### Checkpoint semantics

`cleanup_checkpoint` schema v1 is optional in the existing checksum-protected, version-2 local save document. It stores stable item states (ground, carried, deposited), carried item index, bin occupancy, service authorization and worker route fraction, completion/reward metadata, and terminal tick.

The validator uses the **same** authoritative `civic_session` as the tutorial, wrong-way and parking snapshots. It rejects impossible carrying counts, overfilled bin state, fake service arrival, premature service calls, fabricated rewards, conflicting incident phases, and inconsistent objective or metric history. Actors are staged from fixed safe coordinates before restoring manager data; it does not trust world object IDs from JSON.

F5 saves only if market state and earlier missions validate. F9 refuses a cleanup checkpoint without completed parking history. A checkpoint older than an already-running cleanup mission cannot silently erase the active market scene.

### New regression tests (authored, not run)

- `tests/market_cleanup_live_test.gd`: inspect-before-collect, single-item carry, physical item removal, 2/2 bin, rejected overfill/service-before-full, worker travel, one reward, exact metric deltas.
- `tests/market_cleanup_checkpoint_test.gd`: corrupted item/bin/service states refused, atomic JSON round trip and restored mid-route worker position, continued cleanup and reward idempotence.
- `tests/market_cleanup_card_test.gd`: action labels and typed dispatch; unknown action falls back to ordinary report and disabled action does not dispatch.
- Existing `gameplay_persistence_test.gd` and `parking_checkpoint_test.gd` now check that **historically completed** earlier missions still validate after later civic clocks advance.

### Local test commands (Windows PowerShell)

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
$tests = @(
    "market_cleanup_live_test.gd",
    "market_cleanup_checkpoint_test.gd",
    "market_cleanup_card_test.gd",
    "parking_checkpoint_test.gd",
    "gameplay_persistence_test.gd"
)
foreach ($test in $tests) {
    & $godot --headless --path . --script "res://tests/$test"
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
}
python tools/run_regression.py --godot $godot --timeout 120 --report build/game-021-market-cleanup.json
Write-Host "Exit code: $LASTEXITCODE"
```

Expected new PASS markers: `CIVIC_CHAOS_MARKET_CLEANUP_LIVE_PASS`, `CIVIC_CHAOS_MARKET_CLEANUP_CHECKPOINT_PASS`, `CIVIC_CHAOS_MARKET_CLEANUP_CARD_PASS`.

**Acceptance remains open:** Godot 4.7.2 headless import; focused and full local regression tests; PC walkthrough using game controls; Android touch checks; interrupted save/load and blocked service-route tests. These tests were **not run by the assistant**. No GitHub Actions were manually dispatched.

## Known remaining work

- No ending scorecard, campaign-complete transition or Free Roam unlock yet (next GAME-022 milestone).
- The sanitation worker moves along a short unobstructed marked route; it does not have full navmesh pathfinding or responses to crowd collision.
- Procedural props are functional placeholders; litter visuals, sanitation animations, audio, local-language text and crowds need visual polish.
- Player inventory indicates carrying via prompts and item disappearance; a visible handheld wrapper model and inventory indicator are not yet implemented.
- Runtime end-to-end validation of the earlier GAME-014 through GAME-020 checkpoints remains pending, and latest CI failure analysis is deferred to the release-stage gate as requested.

**Numbering note:** The original `IMPLEMENTATION_BACKLOG.md` used GAME-021 for proposed emergent event cascades. Later implementation continuation milestones GAME-017–020 were dedicated to persistence/traffic recovery. This document labels the newly implemented market-cleanup feature GAME-021; the older planning table must be reconciled rather than treated as evidence that the event-cascade task is complete.
