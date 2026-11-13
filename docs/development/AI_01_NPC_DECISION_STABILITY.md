# AI-01 — NPC Utility Decision Stability (staged, not activated)

**Status:** Source and a focused regression fixture implemented on `fix/aud-001-game024-gate-hardening`. **Not engine-tested and not connected to live district pedestrians.** The release/activation gate is still PR #49's full Godot 4.7.2 acceptance.

## Source skills applied

The user-provided `awesome-gamedev-agent-skills` pack's `ai-behavior-trees-utility-ai` skill and `references/utility-ai-system.md` recommend normalized 0..1 considerations, a current-action hysteresis bonus, deterministic tick cadence and hard gating of unsafe actions. Its `best-practices-and-pitfalls.md` emphasizes preserving per-agent state, seed-based reproducibility, reactive safety interrupts and not rebuilding entire behavior trees each frame.

This milestone retains `CivicNpcUtilityEngine.choose()` as the original scoring authority. New `scripts/npc/npc_decision_stability.gd` is a lightweight `RefCounted` **policy wrapper, not a second scoring engine**.

## Contract

- Each policy instance belongs to **one NPC**. Calls with another NPC ID fail without mutating the incumbent policy; explicit `reset()` is required to reuse a policy.
- Stable fixed-tick hold (default 6 simulation ticks) plus 0.08 score margin prevents oscillating near-ties. After the hold, a clearly stronger **eligible** action can take over; equal or near-equal scores maintain the current action.
- **Safety wins immediately:** any action the raw scorer excludes (red/blocked crosswalk, unsafe assistance) is abandoned that same tick, regardless of hold or hysteresis. Waiting remains the fail-closed fallback on invalid inputs. Policy never overrides raw action eligibility.
- Each `decide` uses the existing deterministic utility scorer with the provided seed and `CivicNpcBlackboard`; no wall-clock timers, Node instance IDs or global RNG.
- Malformed/nonfinite observations, stale ticks, wrong NPC, invalid policy tunables and invalid saved policy state fail closed.
- The optional schema-v1 `snapshot()`/`restore()` round-trips through JSON with exact integer-valued fields. **No migration or change to the game's existing civic/save schema is made.** Integrate this per-agent data only after the release gate.

## Focused test

`tests/npc_decision_stability_test.gd` exercises:
1. 120 fixed ticks alternating normalized near-tie conditions without switching from the initial wait.
2. A stronger legal action switching after hold; red signal **on the same tick** interrupting a held crossing; a cool-down before the next crossing.
3. Safe-to-help becoming unsafe on the same tick; invalid input and stale tick rejection.
4. Cross-agent isolation and explicit reset.
5. A 40-tick identical-seed replay, JSON snapshot round-trip, rejection of malformed future-tick/unknown-action saved state, and continuation from restored policy.

Registered as **fixture #100** in the mandatory regression runner and **focused check #20** in the Windows gate. `tools/check_game024_gate.py` now requires both counts. Its 40-tick trace also runs as **the fourth cross-process deterministic replay**, validated through the strict Python harness. These are executable test definitions, **not successful Godot results**.

## Activation after AUD-001

Do **not** change `district_pedestrians.gd`, GAME-025 movement/routines, mission rewards or checkpoint logic yet. After exact SHA gate passes and AUD-002 campaign/save testing is accepted:
1. Add one policy per spawned NPC; bind its ID, blackboard and fixed decision tick. Reuse the policy until the NPC despawns.
2. Provide an opt-in feature flag, default **false**, and a direct rollback toggle.
3. Connect the selected **safe** action to movement/feedback, with red-light conditions rechecked at the point of physical action.
4. Measure decision time and NPC actor count before enabling and after, on real Android and desktop profiles.
5. Run the complete Godot suite plus manual campaign/Free Roam and F5/F9 consistency checks before enabling for users.

**Next dependent tasks:** responsive touch controls [#51](https://github.com/gauravprajapat-23/civic-chaos/issues/51), measured traffic/crowd performance [#52](https://github.com/gauravprajapat-23/civic-chaos/issues/52). Do not run GitHub Actions.
