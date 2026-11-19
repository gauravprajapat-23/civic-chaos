# AUD3-MAP-02 — City Navigation Routes and Landmarks

**Branch:** `fix/aud-001-game024-gate-hardening`
**Status:** Code + focused regression committed; Godot 4.7.2 and PC/Android acceptance not run by this session.

## Shipped source

- `scripts/ui/civic_map_routes.gd`: deterministic shortest-path walk guidance on the *existing* `CivicRoadGraph` intersection endpoints, using actual lane lengths as weights. Traversal is undirected for pedestrians and does not modify vehicle right-of-way.
- `scripts/ui/civic_city_map.gd`: green road route overlays in minimap/full map, current active mission waypoint pin, live player arrow, road-route metres and direct-line metres, and selectable destination buttons.
- Selectable destinations are the **active mission marker** (only when `guidance_state().has_target` and a real `Vector3 target` exist), **Market Chowk** (0,0), **West Approach** (-46,0), **East Footpath** (46,0), **North Market Road** (0,-46). Landmark names identify map areas, not new quests or official district definitions.
- `scripts/core/main.gd`: gives the map the same validated graph as FourWayJunction and refreshes position/objective with the existing guide every 0.5 seconds.

## Scope & limitations

- PC M / Android MAP open the existing paused full-map overlay. Choose MISSION/CHOWK/WEST/EAST/NORTH inside the map, CLOSE/M to return. Selecting a landmark does **not** alter the active quest.
- World-to-map north is -Z and the road display uses `CivicCityRoadLayout` axes, consistent with the game's existing coordinates.
- Route geometry connects a player's off-road position to the nearest road intersection, and the goal from its nearest intersection. These short access connectors are guidance only; they do not guarantee a collision-free footpath.
- This is static shortest road distance, not vehicle navigation, traffic-aware ETA, live crossing permission, GPS or a walkable navmesh. No shortcuts through restricted areas are asserted.
- No server, map API or copied imagery.

## Acceptance commands

```powershell
cd "C:\Users\gauravp\Projects\civic-chaos"
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/aud3_city_map_test.gd
& $godot --headless --path . --script res://tests/aud3_city_map_routes_test.gd
& $godot --path .
```

Check Godot stderr as well as exit codes; a PASS marker alongside ERROR is not acceptance. Run the project’s full regression and mobile input/safe-area suites before APK sign-off.

## PC/Android manual checks

1. Verify player arrow moves smoothly and route distance changes with travel; mission pin comes from current physical guidance target.
2. Mission with `has_target=false` should show no invented pin/route. Manual landmark destinations may still be selected.
3. Press M/open MAP, select each destination and return to MISSION; game remains paused throughout.
4. Switch portrait/landscape, check legibility and touch-map button overlap against mission guide/HUD.
5. Complete the wrong-way / parking / cleanup sequence and verify navigation changes with real active mission actors.
