# CC-028 Wrong Way Disaster Mission

`CivicWrongWayMission` composes the existing road graph, illegal connector scenario, incident manager, player interaction service and mission objectives. `setup()` registers the mission. `begin(offender_id)` starts the obstruction. `advance(demand)` updates congestion deterministically. After at least four queued vehicles, `report(player_id, distance_m)` uses permission and distance checks. `intervene()` records the marshal response. Once the queue clears and remains clear for three ticks, the incident resolves and the mission completes. `reward()` is idempotent.

The test runs an end-to-end scripted replay with early-report rejection, distance checks, queue growth, intervention, sustained recovery and duplicate reward prevention.

**Outstanding:** This is a scripted vertical-slice *logic flow*, not a playable 3D mission. It still needs a mission trigger, traffic visuals, player interaction HUD, live vehicles, save wiring and a manual gameplay walkthrough.
