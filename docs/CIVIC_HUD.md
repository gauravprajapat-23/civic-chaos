# CC-031 Traffic and Civic HUD

`CivicStatusHUD` displays mission objective progress, incident count, city reputation, traffic statistics and player feedback. It uses wrapping labels and a screen-anchored panel. Missing telemetry displays **No live data** or **--** instead of invented values.

The main scene creates the HUD and connects player/lifecycle feedback. The existing F1 pause behavior hides the HUD. To feed real gameplay state, call `civic_hud.render_state({"mission": mission_dict, "incidents": count, "reputation": score, "traffic": spawner.metrics(), "feedback": message})` from a world coordinator. Mission, incident, reputation and traffic sources are not yet mounted together in the live scene.

Run `godot --headless --path . --script res://tests/civic_hud_test.gd`. Manual viewport scaling and pause checks remain required.
