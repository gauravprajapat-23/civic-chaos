# WORLD-002C — Drivable Organic Perimeter Road Expansion

**Scope:** safe first WORLD-002C increment on PR #92: replacing two existing east-perimeter straight street sections with **actual curved 3D asphalt and colliders**, matching both the canonical road data and traffic lanes. This deliberately does not insert a new junction or reassign saved lane IDs.

## Why not add arbitrary junctions yet?

WORLD-001F checkpoint compatibility expects graph schema version 1, exactly 40 physical undirected edges, 80 directed lane IDs from 100–179, and predictable connector legality. The world map and vehicle graph both call `CivicCityNetworkDefinition.roads()`. A new junction would need a save migration, traffic priority contract, and regression for the new branches. We will not silently invalidate those systems simply to add a visual street.

## Grounded connections

| Canonical existing road | Lane IDs (forward/reverse) | New geometry |
| --- | --- | --- |
| East outer north: (120,-120) → (120,-46) | 172 / 173 | 25-point inward S-bend, 2.8 m displacement |
| East outer south: (120,46) → (120,120) | 178 / 179 | 25-point inward S-bend, 2.8 m displacement |

These roads already connect to real junctions. Their endpoints, junction connections, speed limits and traffic lane identities are unchanged. The two opposing driving lanes are offset onto left-hand traffic shoulders with a 4 m junction ramp; they are drawn from the *same* sampled centerline as the asphalt ribbon.

## Code integration

- `scripts/world/world_002_road_curves.gd` — single source for both new sampled centerlines, left-hand lane offsets, physical asphalt mesh. Uses existing OrganicRoad.surface_mesh() rendering, not a separate hand-drawn curve.
- `scripts/world/city_network_definition.gd` — marks exactly the two east edges `world_002_curve` and supplies their canonical `centerline`. Stable 40-edge order, 80 lane IDs, schema-1 contract.
- `scripts/world/junction_builder.gd` — route graph uses `EastCurves.driving_lane` on these two edges, preserving the original junction endpoints and legal outgoing connections.
- `scripts/world/neighborhood.gd` — replaces previously full-length straight east road asphalt by one central straight segment under historical `PerimeterRoad_NS_1` name, short junction caps and two separate true curved StaticBody3D roads with trimesh collision, `World002EastRoad_North` / `World002EastRoad_South`. Old straight asphalt no longer overlaps the new paths. The original west organic road is unchanged.
- `tests/world_002c_organic_roads_test.gd` — checks sampled map/network lanes and physical road identity, opposite-lane clearance at apex, stable road IDs, old save geometry reachability, zero duplicate full-length straight east collider, and prior world elements.

## Windows native verification (Godot 4.7.2)

**Not executed in this hosted environment.** Native import, scenario tests and rendered input are required before release.

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$path = "C:\Users\gauravp\Projects\civic-chaos-world-002a-review"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
git fetch origin
if ($LASTEXITCODE -ne 0) { throw "Fetch failed" }
if (-not (Test-Path $path)) {
    git worktree prune
    git worktree add --detach $path origin/feature/world-002-organic-neighborhoods
} else {
    $changes = @(git -C $path status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $changes.Count -gt 0) {
        throw "Tracked edits in review worktree"
    }
    git -C $path switch --detach origin/feature/world-002-organic-neighborhoods
}
if ($LASTEXITCODE -ne 0) { throw "Worktree checkout failed" }
Push-Location $path
try {
    $import = & $godot --headless --path . --editor --import --quit 2>&1 | Out-String
    $code = $LASTEXITCODE
    $import | Out-Host
    if ($code -ne 0 -or $import -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)') { throw "Import failed" }

    foreach ($test in @(
        "world_002c_organic_roads_test.gd",
        "world_002b_public_spaces_test.gd",
        "world_002a_block_layout_test.gd",
        "world_001e_map_parity_test.gd",
        "world_001f_save_contract_test.gd",
        "road_footpath_01_crossing_test.gd",
        "aud3_city_map_test.gd"
    )) {
        $output = & $godot --headless --path . --script "res://tests/$test" 2>&1 | Out-String
        $code = $LASTEXITCODE
        $output | Out-Host
        if ($code -ne 0 -or $output -match '(?m)^\s*(ERROR:|SCRIPT ERROR:|FATAL ERROR:)' -or
            $output -notmatch '(?m)^CIVIC_CHAOS_[A-Z0-9_]+_PASS\s*$') { throw "FAILED: $test" }
        Write-Host "PASS: $test" -ForegroundColor Green
    }
    Write-Host "7/7 WORLD-002A/B/C CHECKS PASSED" -ForegroundColor Green
} finally { Pop-Location }
```

## Rendered acceptance — Windows and Android

1. Drive both directions on new east curves using car and bike. Confirm physical wheels follow the visible asphalt, no abrupt gap or collision seam at four endpoints.
2. Test pedestrians at east sidewalk/intersections; no invisible straight barrier remains, and corner lanes remain connected.
3. Watch two-way NPC traffic at both curve apexes for head-on collisions, drift, sticking, jitter and turning failure.
4. Save and restore vehicles on lane IDs 172,173,178,179; compare route progress and traffic continuation with schema-1 checkpoints.
5. Open the full city map and minimap (particularly PR #91 after independent integration) to confirm both follow the sampled east centerlines and mission route overlays.
6. On Android, inspect terrain mesh rendering, collision, pop-in and FPS under load. Keep PR draft until results are recorded.

## Future expansion

**WORLD-002C2** can add a truly new T-junction or connected branch only after traffic review of intersections and save-schema migration. Current milestone expands real organic streets **without adding new network edges**. This is intentional rather than inventing an unsafe street on top of occupied lots.

No edits to `scripts/core/main.gd`; no GitHub Actions manually started; branch remains draft and unmerged.
