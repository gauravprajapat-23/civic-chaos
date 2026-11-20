# WORLD-001F — Organic City Release Acceptance

Candidate: `feature/world-001-organic-city` / draft PR #88.
**Do not merge until ALL local, rendered, save and physical Android gates are recorded.**
No manually triggered GitHub Actions.

## 1. Automated local Windows gate

Use **fresh detached** checkout of the latest PR head. The script explicitly rejects any SHA except the `-ExpectedCommit` argument and fails on dirty source files, missing tests, nonzero exits, missing PASS markers, engine ERROR/SCRIPT ERROR messages, timeouts and Android export failures. This includes WORLD-001A–F, stop-line, central spillback, pedestrian, dispatch permission, MAP/HUD, and motorcycle impact regressions.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
git fetch origin
$review = "C:\Users\gauravp\Projects\civic-chaos-world-001f-review"
if (Test-Path $review) { throw "Inspect existing worktree first" }
git worktree add --detach $review origin/feature/world-001-organic-city
if ($LASTEXITCODE -ne 0) { throw "Unable to create review checkout" }
Push-Location $review
try {
    $sha = (git rev-parse HEAD).Trim()
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\world_001f_verification.ps1 -ExpectedCommit $sha
    if ($LASTEXITCODE -ne 0) { throw "WORLD-001F gate failed" }
} finally { Pop-Location }
```

Outputs are `build/world-001f/report.json` and per-test `*.stdout.log` / `*.stderr.log`. Attach the report and **the actual head SHA** to PR #88 before approval. Running only an older head does not accept the current branch.

## 2. Existing checkpoint compatibility

- Verify F5/F9 while cars are stopped at the west T-junction and while a route uses lane IDs 102/103.
- Load a **pre-WORLD-001** user checkpoint from `main`, where applicable; copy the file first. Do not overwrite production save data with this branch.
- On a legacy save, confirm all lanes remain valid, route progress does not spawn a car inside a building/other actor, and pedestrian & signal state is intact.
- Verify wrong-way report/tow service, parking, market cleanup, full district finale/Free Roam, and UI route selection survive save/reload.
- Invalid saves must be rejected *without* losing the running fleet or counters.
- **Current limitation:** JSON traffic snapshot schema still records lane ID + arclength, not topology fingerprint. WORLD-001B preserves lane IDs and endpoints but modifies the western road's geometry, so the restored world position for a historic car can shift a small distance. This is an explicit release risk requiring physical acceptance; the new test does NOT claim migration of all real historical saves.

## 3. Rendered Windows/PC driving gate

Record pass/fail and screenshot/video per row:

| Scenario | Expected acceptance |
|---|---|
| West bend (x=-120,z=-83) | Asphalt visibly curved, player/bike/car physically supported, neither NPC lane leaves pavement |
| West T (x=-120,z=-46) | Side road yields to collector; after zone clears, traffic releases; no two conflicting entrants |
| Give-way sign | Placed out of lane and visible, no artificial 4-way signals on this one node |
| Other signalized nodes | Still obey red/green/clearance and pedestrians; emergency responder also respects permissions |
| Map and minimap | Exact road bend is drawn; player direction/mission pin and route overlay stay on real road geometry |
| Bus stop, park, shops, parking | Props visible; no collision trapping on sidewalks or road; correct scale/no floating assets |
| MAP/CALLS overlay and rotation | Safe area, tap targets, current call and waypoint state preserved |
| F5/F9 with car on bend | Cars/route progress/waypoint restore without collision or disappearance |
| Full linked campaign and Free Roam | Three missions, responder, scorecard, replay/save and target navigation remain playable |

## 4. Android debug export and device gate

After **Windows tests pass**, rerun the same exact SHA with `-BuildApk` (Godot export preset `Android Debug` must exist, SDK/JDK/signing correctly configured).

```powershell
$sha = (git rev-parse HEAD).Trim()
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\world_001f_verification.ps1 -ExpectedCommit $sha -BuildApk
if ($LASTEXITCODE -ne 0) { throw "Android gate failed" }
```

APK: `build/android/CivicChaos-WORLD-001F-debug.apk`. Export success is **not** device acceptance. Install on a representative target Android device and test real on-device:
- Landscape and portrait/rotation where supported; display cutouts/safe margins, pause/resume, stuck touches, MAP/CALLS modal focus
- Player on-foot, mount/dismount, bend drive-through, brake/reverse and close car contact without penetrations
- Signal/priority T crossing under normal, saturated and pedestrian traffic
- F5/F9 equivalent device save/load controls and app background/restore
- Capture measured sustained frame rate, frame spikes, memory, draw calls and device thermal behavior for 10 minutes of representative play. Attach device model, Android version, capture method and actual measurements; **no fabricated FPS target or PASS**

## 5. Acceptance signoff

- [ ] Exact-commit WORLD-001F gate PASS (all tests, no engine errors, clean tree)
- [ ] Existing GATE-01 compatibility evaluated and discrepancies documented
- [ ] Legacy save/device checkpoint tests PASS (real saves, not only synthetic records)
- [ ] Rendered Windows traffic + mission / navigation / collision acceptance PASS
- [ ] Android debug APK export PASS
- [ ] Actual Android device controls, save, performance acceptance PASS
- [ ] PR #88 file ownership/diff and no accidental changes to `main` verified
- [ ] Master integration owner approves release; only then merge PR #88

The world is intentionally **one organic pilot**. Completing WORLD-001F does not mean the whole five-axis city has already been replaced by an organic road network.
