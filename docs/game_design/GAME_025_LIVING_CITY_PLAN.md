# GAME-025 — Living City Expansion (implementation plan; runtime gate blocked)

**Current state:** Planned, no GAME-025 gameplay code is authorized until `tools/verify_game024.ps1` produces a passing local Godot 4.7.2 report and all related tests pass.  
**Foundation:** `feat/game-024-dynamic-free-roam`, with deterministic pedestrians, the event director, a physical E/USE card, mission scoring, and verified F5/F9 schema contracts.  
**GitHub Actions:** Do not dispatch, rerun, or rely on workflows for this milestone.

## Gate 0 — GAME-024 local verification

1. Switch to `feat/game-024-dynamic-free-roam` and run `powershell -ExecutionPolicy Bypass -File tools/verify_game024.ps1` in Windows PowerShell.
2. Confirm `build/game-024-verification.json` has `status: passed` on the exact tested commit and `build/game-024-regression.json` has `passed: true`.
3. Investigate and repair any import errors, missing PASS markers, dynamic-location collision issues, negative-path failures, NPC reaction errors or legacy v1 migration failures **before** starting GAME-025.
4. Confirm manually that players can interact through E and Android touch controls at relocated evidence and the campaign finale remains repeatable only as a read-only scorecard.
5. Preserve the accepted GAME-024 commit SHA in GAME-025 implementation notes to avoid silently building on an unverified state.

## GAME-025 feature slices (after Gate 0)

### 025-A: Daily routine simulation

- Implement `scripts/npc/npc_daily_routine.gd` as a deterministic pure-data scheduler, not a second physics controller.
- Four initial role archetypes: commuter, shopkeeper, sanitation worker, neighborhood resident.
- Schedule phases: morning commute, work/errands, lunch/leisure and return-home. Use *simulated* district time derived from existing fixed-step clock; never query wall-clock time.
- Each walker gets an ID, occupation, destination and current routine state. The current route-planning, stop-line, crossing reservation and collision avoidance stay authoritative; a schedule can request a destination but **never teleport** a pedestrian there.
- Changing density must not break the existing `_walkers` array indexing, crossing reservation ownership or save/restore invariants. Default existing 8 walkers preserved until explicit tests prove scaling safe.

### 025-B: Contextual conversations

- Conversations triggered only with the existing E/USE interaction affordance within the player's 3 m interaction range; no global click-to-reward.
- Context mixes civic reputation, currently active Free Roam challenge, role/time-of-day, and nearby events.
- NPCs respond differently to an obstructed sidewalk, litter cleanup, unsafe parking and a resolved safety task. NPC speech is not a new civic reporting authority.
- Support 3–4 dialogue variants per role with deterministic selection, 2–3 word compact prompts and future localization keys rather than hard-coded UI logic.
- All dialogue is bounded and interruptible; no conversation can consume a mission-specific E/USE action or create an extra score receipt.

### 025-C: Crowds that feel real but remain safe

- Introduce ambient foot-traffic density presets (quiet/normal/busy) as **per-tick limits**; cap added NPC count according to platform and scene state.
- Add groups gathering near safe market spaces only where static and dynamic collision clearance succeeds.
- Avoid crowd pileups around traffic crossings, parked vehicles, incident evidence and active interaction props.
- Limit LOD-sensitive conversation/animation updates to nearby agents. When a budget would be exceeded, defer spawn or skip cosmetic updates, never violate collision rules.
- Retain deterministic replay and ensure active crossings are released on despawn.

### 025-D: Visible consequences, not fake score

- Track local cleanliness, pedestrian confidence and market accessibility as an **observable district presentation state** derived from the authoritative civic event ledger and the last-known event resolutions.
- After a successful litter cleanup, update nearby NPC dialogue and a street visual. After an ignored priority incident, nearby pedestrians express concern; no automatic Trust/Safety penalty unless backed by an explicit authorized, audited outcome.
- Keep presentation effects idempotent across checkpoint reloads. The same incident ID must not spawn duplicate effects or duplicate civic rewards.
- Persist consequences in a separately validated schema with backward-compatible defaults; never mutate the existing story finale reward or civic history during load.

### 025-E: QA and release readiness

- Seeded routine replay test, state transitions over time, collision-safe movement and no crosswalk reservation leaks.
- Conversation proximity/selection/disabled-state test, input/card priority conflict test.
- Foot-traffic cap, crowded intersection, frozen/waiting pedestrian and high/low LOD tests.
- Civic consequences exactly-once, expiry-vs-resolution distinction, F5/F9 migration, and repeated restore test.
- Run Godot 4.7.2 import, focused tests, strict full regression and manual PC/Android walkthrough.
- Only then mark the GAME-025 milestone completed; keep Actions disabled.

## Build order

`Gate 0 → 025-A routines → 025-B dialogue → 025-C crowds → 025-D consequences → 025-E testing`.

This plan is intentionally separate from the older first-playable backlog's GAME IDs, which predate the campaign's later GAME-022–025 milestone naming. The current milestone labels refer to the live user-requested campaign continuation sequence.

## Anti-regression constraints

- Offline-only: no backend required.
- Never bypass traffic-light safety or existing physics collision tests.
- Do not instantiate a parallel civic score manager.
- Preserve campaign completion, event cooldowns, replay determinism and safe save rollback.
- Require local engine evidence to mark any milestone as verified. Source-only review is insufficient.
