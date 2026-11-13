# GAME-023 — Repeatable Free Roam Civic Events

**Date:** 2026-11-07  
**Branch:** `fix/regression-nov05`  
**Status:** Source and regressions committed; Godot 4.7.2 runtime execution pending.

## Overview

After completing the four campaign milestones and acknowledging the GAME-022 finale, Civic Chaos now starts the **Free Roam events** system. Market Chowk remains a continuously simulated district with live traffic and pedestrians. This milestone adds **new civic activity**, but does not reset the campaign, fabricate story rewards, or require a backend.

Two initial mini-incidents reuse the existing **E / USE** world interaction, detail card, and live civic ledger:

| Activity | Physical sequence | Verified civic outcome |
|---|---|---|
| Fresh litter | Inspect a visible wrapper → pick it up → physically use the green bin | Cooperation +2, Trust +1 |
| Fallen public sign | Inspect the fallen sign → pick it up → place it at the marked blue safety stand | Safety +2, Efficiency +1 |

An active object disappears from its world position only after collection. The mission guide points to the **actual** current world object or destination. The game does not award points if the player has not finished both steps. The HUD shows completed and expired Free Roam activities, and the scorecard remains read-only: opening F2 results never grants rewards.

### Seeded scheduler and limits

`CivicEventDirector` supplies deterministic selection, a seeded RNG, explicit one-unit resource budget, at most **one active** civic incident, distinct event IDs, finite lifetimes and a **20-second cooldown**. The Free Roam loop uses a 1-second logical tick, starts the first activity shortly after gameplay resumes, and keeps events alive for up to 180 logical seconds.

An ignored activity expires and is closed in the incident audit log **without player points**. No simultaneous pile-up of repeatable event props occurs. Event resolution releases the cost only once and cannot be repeated to farm Trust or Safety.

The scheduler's **canonical snapshot** contains a decimal-string RNG state, fixed definition compatibility, remaining budget, active event identity, cooldown timestamps, expiry, history and next instance. The restore validator checks that the sum of available budget and live event costs equals the configured total; invalid RNG, impossible routes through the event state machine, unknown event kinds and forged IDs are rejected.

### Offline checkpoint integration

F5 retains the existing checksum-verified GAME-018 v2 document and optionally adds:

```json
"free_roam_checkpoint": {
  "schema_version": 1,
  "tick": 410,
  "seconds": 0.25,
  "next_spawn_tick": 430,
  "resolved_total": 2,
  "expired_total": 1,
  "active_event": {},
  "director": {"schema_version": 1, "...": "verified scheduler state"}
}
```

The `director` excerpt above is schematic, not a literal file template. The **real save** includes the full event-director snapshot, validated against the same authoritative `civic_session` as campaign and Free Roam incidents.

Checkpoint preflight requires:
- Four completed canonical story milestones and an acknowledged, verified campaign finale.
- A valid scheduler with conserved budget, known event definitions, stable instance identity and correctly bounded timers.
- Exactly one live event at most, correctly linked to its ACTIVE `CivicIncidentManager` incident and distinct instance source.
- No score receipt for an unresolved event; `resolved_total` equals the number of recorded, idempotent Free Roam outcome receipts.
- A valid 1-second tick fraction and monotonically compatible incident manager state.

A saved **mid-carry** state hides the ground object when rehydrated; a resumed deposit uses the **same incident ID**, not a new one. Older GAME-022 campaign checkpoints without a `free_roam_checkpoint` start a fresh event scheduler after the finale acknowledgement.

Attempting to rewind the current active Free Roam session to an older checkpoint without a Free Roam snapshot is deliberately rejected; restart the level first rather than silently erasing ongoing civic activity.

### Code

- `scripts/civic/event_director.gd`: explicit one-time event resolution, budget conservation, JSON-safe saved RNG and verified restore without changing existing `snapshot()` for deterministic tests.
- `scripts/civic/free_roam_events.gd`: live physical civic activities, deterministic scheduler, inspected/held/deposited states, cooldown, expiration, one-time score receipts, guidance, and checkpoint restore.
- `scripts/civic/cleanup_target.gd`: reused green recycling bin plus new physical fallen-sign and safe-stand shapes.
- `scripts/core/main.gd`: creates Free Roam events only after acknowledged finale; connects E/USE card, F5/F9 save/load, HUD and guide. Completed story objects retain their previous state.
- `scripts/ui/civic_incident_card.gd`: explicit `collect_sign` and `place_sign` actions; unknown actions still fall back to the original report behavior.
- `scripts/ui/civic_status_hud.gd`: completed/missed Free Roam counts and active event status, without fabricated score deltas.
- `tools/run_regression.py`: new executable regression files registered; no change to the strict error/negative-path rules.

### Authored tests — Godot execution not yet confirmed

1. `free_roam_director_checkpoint_test.gd`: seeded events remain deterministic after JSON restore; corrupt event budgets, RNG and instance IDs are refused.
2. `free_roam_live_events_test.gd`: real object inspection, collection, physically valid placement, exactly-once score receipt and subsequent bounded event.
3. `free_roam_event_restart_test.gd`: verified save mid-carry, destroy/rebuild world, restore actual prop state, recover exact incident ID, reject forged event state and duplicate scoring.
4. `free_roam_card_test.gd`: typed action labels, disabled action refusal and no accidental generic report submission.
5. `free_roam_expiry_test.gd`: ignored event expires without reward or instantaneous respawn, releases its scheduler budget and leaves a valid checkpoint.

Expected markers: `CIVIC_CHAOS_FREE_ROAM_DIRECTOR_CHECKPOINT_PASS`, `CIVIC_CHAOS_FREE_ROAM_LIVE_EVENTS_PASS`, `CIVIC_CHAOS_FREE_ROAM_EVENT_RESTART_PASS`, `CIVIC_CHAOS_FREE_ROAM_CARD_PASS`, `CIVIC_CHAOS_FREE_ROAM_EXPIRY_PASS`.

## Windows local verification

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

$tests = @(
  "free_roam_director_checkpoint_test.gd",
  "free_roam_live_events_test.gd",
  "free_roam_event_restart_test.gd",
  "free_roam_card_test.gd",
  "free_roam_expiry_test.gd",
  "district_campaign_unlock_test.gd",
  "district_finale_checkpoint_test.gd",
  "market_cleanup_live_test.gd",
  "save_resilience_test.gd"
)
foreach ($test in $tests) {
  & $godot --headless --path . --script "res://tests/$test"
  if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
}

python tools/run_regression.py --godot $godot --timeout 120 --report build/game-023-free-roam-report.json
Write-Host "Exit code: $LASTEXITCODE"
```

## Acceptance and remaining work

- [x] Source: two physically interactable repeatable incident types
- [x] Source: seeded, bounded scheduler with safe expiry and distinct civic receipts
- [x] Source: score/HUD/guide and F5/F9 campaign integration
- [x] Source: five executable test scripts and strict runner registration
- [ ] Actual Godot 4.7.2 compilation, focused tests and combined regressions
- [ ] Manual PC/Android gameplay, signal/crossing/prop collision safety at the fixed incident spots
- [ ] Additional event types, dynamic locations, repeatable NPC dialogue, animations, audio and meaningful escalating Free Roam challenges
- [ ] Stronger pre-staging validation when restoring Free Roam actors into changing physical-world occupancy
- [ ] Full release testing of GAME-014–023 remains deferred until the user opens the release gate

**Caution:** The fixed positions are an MVP. There is no dynamic street-placement solver for repeatable props yet. The earlier city-wide restore remains best-effort when live geometry prevents physical restaging. An interrupted restore of the scene's Free Roam props can require reloading the checkpoint.

No workflows were started. Both GitHub Actions files remain manual-only by request; using a new report filename preserves the locally modified `build/regression-report.json`.
