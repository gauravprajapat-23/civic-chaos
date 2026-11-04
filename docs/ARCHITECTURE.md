# Civic Chaos — Foundation Architecture

## Design rules
- Scenes own visuals; systems own decisions and simulation state.
- Gameplay systems are modular and explicitly wired by the world root.
- Avoid adding speculative autoload singletons before their APIs are designed.
- Traffic will use a directed lane graph, not pedestrian navmesh routing.
- NPCs will use utility decisions plus state machines.
- Headless smoke checks must run before closing an issue.

## Current implementation
`scenes/core/main.tscn` is a simple visible test environment with a ground plane, camera and label. `SceneRegistry` enumerates placeholder module roots. These roots are intentionally empty until their respective issues are implemented.

## Next issues
CC-002: GitHub Actions validation. CC-003: deterministic simulation clock. CC-004: player controller. CC-005: lifecycle and save.
