# AUD3-MAP-01 — City navigation map

**Status:** Source implemented; Godot 4.7.2 and device acceptance pending.

## Gameplay controls

- PC: press **M** to toggle the full-screen map.
- Android: tap the **MAP** button (under the minimap); tap **CLOSE** to return.
- The minimap remains visible in ordinary gameplay.
- Opening the map suspends the simulation through the existing lifecycle pause API and releases any held touchscreen gestures. Closing restores the prior gameplay controls and mouse capture.

## Live world data

- `CivicCityRoadLayout.coordinates()` supplies the five real road axes; the same layout builds the city graph.
- Player position comes from `PlayerRoot.global_position`; arrow direction comes from the player transform.
- Only a real current `guidance_state()` with `has_target=true` and a `Vector3 target` displays the gold mission pin. A mission with no actionable physical target is not assigned an invented marker.
- This map is a street-plan overview, **not** turn-by-turn routefinding or GPS.

## Acceptance checklist

1. Import Godot 4.7.2 without parse errors.
2. Run `tests/aud3_city_map_test.gd`; ensure PASS and no `ERROR:`.
3. Complete existing focused HUD/mobile guide tests, and full local regression before release.
4. On PC: player blue arrow moves as walking; M opens/closes; no player motion continues while map open; actual yellow waypoint changes between tutorial, wrong way, illegal parking, and cleanup.
5. On Android: MAP/CLOSE targets work at portrait/landscape resolutions and do not overlap action controls; check screenshots at real device safe-area insets.
6. Verify incident card, district finale, pause panel, and save/load remain unchanged. Do not manually run GitHub Actions.

No Google Maps/network/API or copied GTA artwork/assets are used.
