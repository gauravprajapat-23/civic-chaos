# WORLD-002B — Public Spaces and Distinct Streetscapes

## Purpose and scope

Second implementation milestone under WORLD-002 (draft PR #92) to move the **physical 3D city**, not merely its map, away from identical blocks. Builds on WORLD-002A's staggered building colliders and four facade identities.

The current road network is still 40 edges / 80 stable lane IDs, with the west organic S-bend. This milestone does **not** create a new street, side road, sidewalk collider or a GTA-scale navigable district. New public squares are decorative, deliberately non-physical walkable visual surfaces and furniture. No NPC AI or activity logic introduced.

## Places included

| Name | World X/Z | Existing adjacent block | Identity |
| --- | --- | --- | --- |
| West Garden Square | -93, -91 | northwest block | raised planters, benches |
| Heritage Court | -93, 92 | southwest block | heritage marker, benches |
| Neighborhood Square | 93, -92 | northeast block | community noticeboard, benches |

All three are deterministic low-poly spaces with distinct material palettes, shallow paved surfaces, decorative furnishings and 3D labels. All added nodes are MeshInstance3D / Label3D only; they have **no physical collision shapes**. The prior Public Parking at (95, 92), Old Bus Stop at (-92, 11), CommunityPark and mission-related geometry remain in place.

## Contracts

- `scripts/world/world_002_public_spaces.gd`: pure plot inventory, X/Z bounds, 8m axis clearance, checks against actual WORLD-002A building collider footprints plus 1m buffer, decorative build.
- `scripts/world/neighborhood.gd`: one call to construct public-space visuals after existing World-001D details. The street and collision construction loops are unchanged.
- `tests/world_002b_public_spaces_test.gd`: validates plot positions, collision clearance, shape and label render nodes, absence of physical bodies, old services and park, road edge and lane ID counts, west curved road identity.
- There are no edits to `scripts/core/main.gd`, any traffic scripts, mission/save systems, road meshes or map PR #91.

## Windows native gate — Godot 4.7.2

**Unverified in this environment:** the test has been committed but not executed using Windows Godot. Do not merge before these tests and rendered acceptance pass.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$review = "C:\Users\gauravp\Projects\civic-chaos-world-002a-review"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
if (-not (Test-Path $review)) {
    git worktree prune
    git worktree add --detach $review origin/feature/world-002-organic-neighborhoods
} else {
    $changed = @(git -C $review status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $changed.Count -gt 0) {
        throw "Tracked changes in review checkout"
    }
    git -C $review switch --detach origin/feature/world-002-organic-neighborhoods
}
if ($LASTEXITCODE -ne 0) { throw "Review worktree setup failed" }
Push-Location $review
try {
    $log = & $godot --headless --path . --editor --import --quit 2>&1 | Out-String
    $exit = $LASTEXITCODE
    $log | Out-Host
    if ($exit -ne 0 -or $log -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)') {
        throw "Godot import failed"
    }
    $tests = @(
        "world_002b_public_spaces_test.gd",
        "world_002a_block_layout_test.gd",
        "world_001e_map_parity_test.gd",
        "world_001f_save_contract_test.gd",
        "road_footpath_01_crossing_test.gd",
        "aud3_city_map_test.gd"
    )
    foreach ($test in $tests) {
        $output = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
        $code = $LASTEXITCODE
        $output | Out-Host
        if ($code -ne 0 -or $output -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)' -or
            $output -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') {
            throw "FAILED: $test"
        }
        Write-Host "PASS: $test" -ForegroundColor Green
    }
    Write-Host "WORLD-002A/B: 6/6 TESTS PASSED" -ForegroundColor Green
} finally { Pop-Location }
```

## Rendered acceptance before merge

- Compare northwest, southwest and northeast street views and overhead silhouette; confirm three recognizably different squares, labels and facades.
- Walk/ride through all three squares and their approaches; no invisible barriers, vehicle trapping, footpath overlaps or distracting floating geometry.
- Visit Old Bus Stop, Parking Court, CommunityPark and all active incidents to confirm existing game locations and collisions still work.
- Inspect west organic street and NPC traffic; existing 40 roads remain authoritative.
- On Android verify low-end device FPS, geometry count, portrait/landscape controls and map coherence. These are **manual** checks; no measured performance claim is made.

**Status:** implementation and tests committed, native Godot and rendered acceptance pending. PR #92 stays draft/unmerged; no GitHub Actions manually run.

## Next step

WORLD-002C must model any new curved roads **once** in authoritative lane/network data, supply matching physical asphalt/collision geometry and navigable intersections, explicitly preserve old traffic checkpoint lane IDs, and rerun full integration. Building additional roads only as decorative meshes is prohibited.
