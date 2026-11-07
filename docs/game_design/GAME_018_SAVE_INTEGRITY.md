# GAME-018 — Save/Load Integrity, Backup Recovery and Restore Guard

Date: 2026-11-07  
Branch: `fix/regression-nov05`  
Status: **Source committed, runtime verification pending (Godot 4.7.2 not run).**

## Goals and scope

Protect Civic Chaos progress against a partial write, damaged JSON, mismatched player/civic generations, and a physics tick advancing a mission halfway through loading. Keep legacy save compatibility while adding verifiable checkpoints.

### File format and crash recovery

`CivicSaveRepository` now writes **version 2**, retaining the existing flat player/civic/mission fields plus `checksum`, a SHA-256 checksum of sorted JSON. It canonicalizes via a JSON parse/stringify round trip before calculating the checksum, because Godot may decode integer JSON fields as floating-point Variants.

**Checksums detect accidental corruption and unsynchronized edits; they are not an authentication or anti-cheat signature.** A person able to change the save and recompute the hash can change both.

Write sequence:
1. Validate required finite player fields; refuse caller-controlled `version` and `checksum`.
2. Serialize to `.tmp`, close/flush, and read it back through the same version/checksum validator.
3. If the existing primary save is valid, copy it to `.bak.tmp`, verify the copy, and promote it to `.bak` as the last known good.
4. Promote the verified `.tmp` to the primary save only after the backup step succeeds.
5. If the current primary is already invalid, **preserve** the existing valid backup rather than replacing it with corrupt bytes.

Read sequence:
- Prefer a fully valid, checksum-verified primary.
- If the primary is absent, truncated, unsupported or invalid, try the last known good `.bak`.
- Never silently load `.tmp`: it may contain an **uncommitted** interrupted write.
- Return an explicit `source` of `primary`, `backup` or `none` with `read_save_detail`; F9 can notify the player when it is using the backup.

**Legacy migration:** correctly shaped version-1 JSON saves without checksum remain readable. The next successful save writes version 2, preserving the previous valid version-1 primary as backup. Unknown/future versions are rejected; migration is not an automatic silent overwrite.

### In-scene restore integrity

- `CivicGameLifecycle.load_player_snapshot(player, saved)` consumes the exact document that the campaign restored, instead of performing a **second file read** that could select a different save generation.
- `CivicCheckpointTransaction` freezes physics processing on the involved civic session, wrong-way mission and parking mission while their state is committed or best-effort rolled back. It restores the previous on/off scheduling on every return path, including when an actor was originally disabled.
- F9 still validates all provided GAME-014 and GAME-017 mission snapshots against the same civic manager document before modifying the world and preserves the earlier collision-checked player recovery.
- The existing rollback path attempts to restore the earlier managers and actors if a world restore fails. The transaction guard now prevents unrelated ticks **within those scene actors** during this operation.

This is not yet a full transaction over **every background city actor, traffic signal phase or external interaction**. World-level snapshots, rollback of physics side effects that occurred before this transaction, and an explicit crash-resumable journal remain future work. No claim of full ACID semantics.

### Files

- `scripts/core/save_repository.gd`: version-2 canonical checksum, verified backup stage, primary-vs-backup selection, v1 read migration.
- `scripts/core/game_lifecycle.gd`: restore from a specific validated document.
- `scripts/core/checkpoint_transaction.gd`: process-state-preserving mission physics guard.
- `scripts/core/main.gd`: single-document F9, backup notice, physics guard and release on rollback/commit.
- `tests/save_resilience_test.gd`: primary, backup, checksum tampering, truncated JSON, interrupted `.tmp`, invalid backup, v1→v2 migration, unknown version and downgrade refusal.
- `tests/checkpoint_transaction_test.gd`: mission freeze, duplicate begin rejection, commit/rollback reactivation behavior, queued deletion safety.
- `tests/save_generation_consistency_test.gd`: real player physics restore of the specific verified generation after a newer save is committed.
- `tests/lifecycle_test.gd`: checks version-2 writes while retaining previously existing invalid-data and menu checks.
- Existing checkpoint tests now remove `.tmp`, `.bak` and `.bak.tmp` fixtures as well as the primary file, avoiding cross-run contamination.
- `tools/run_regression.py`: three GAME-018 tests registered; existing strict Godot engine-error scanning unchanged.

### Windows PowerShell test gate

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git switch fix/regression-nov05
git pull --ff-only origin fix/regression-nov05

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }

$tests = @(
    "save_resilience_test.gd",
    "checkpoint_transaction_test.gd",
    "save_generation_consistency_test.gd",
    "lifecycle_test.gd",
    "gameplay_persistence_test.gd",
    "wrong_way_checkpoint_test.gd",
    "parking_checkpoint_test.gd",
    "multi_incident_checkpoint_test.gd"
)

foreach ($test in $tests) {
    & $godot --headless --path . --script "res://tests/$test"
    if ($LASTEXITCODE -ne 0) {
        throw "Focused test failed: $test"
    }
}

python tools/run_regression.py --godot $godot --timeout 120 --report build/game-018-save-integrity-report.json
Write-Host "Exit code: $LASTEXITCODE"
```

Expected new PASS markers, **not yet observed**:
- `CIVIC_CHAOS_SAVE_RESILIENCE_PASS`
- `CIVIC_CHAOS_CHECKPOINT_TRANSACTION_PASS`
- `CIVIC_CHAOS_SAVE_GENERATION_CONSISTENCY_PASS`

### Manual verification

1. Use F5 twice in the active civic campaign, then inspect the two actual files under Godot's `user://` directory. The primary contains the latest verified generation, the backup contains its valid predecessor.
2. Back up the test files first. Corrupt the **primary** on a disposable test profile, leave the backup valid, then press F9. A backup-recovery message should appear and the older progress should restore safely.
3. Perform the same with both primary and backup invalid. F9 should reject the save, not create cars or award an incident.
4. Save during GAME-013 tow and GAME-016 parking movement, restore and observe real world actor positions and score history. Check that no mission rewards can be collected twice.
5. For migration, load a genuine old version-1 player save, then save once and verify the primary has version 2 and the backup retained version 1.

### Open acceptance and risks

- [x] Source commits, new tests and runner registrations
- [x] Version-1 compatibility and version-2 canonical checksum code
- [x] Backup fallback, interrupted-temp policy and single-document player restore
- [x] Mission physics transaction guard and explicit rollback paths
- [ ] Engine import + focused tests actually pass under Godot 4.7.2
- [ ] Full strict regression suite (including GAME-014/017) passes
- [ ] Physical PC and Android campaign checkpoint/recovery playthrough
- [ ] Strong full-world atomic restore, including background traffic, pedestrian and signal states
- [ ] Versioned migrations for future campaign schema changes beyond legacy player v1

Godot executable is not accessible through the repository connector; runtime testing must be performed in the user's Windows Godot environment. The latest previous GAME-014 terminal checkpoint result was still pending.

No GitHub Actions were manually dispatched; pushing commits may trigger workflows configured in the repository. The report uses a new filename and does **not** change the user's locally modified `build/regression-report.json`.
