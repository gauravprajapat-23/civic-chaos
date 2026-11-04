# Lane Graph Contract — CC-006

A `CivicLaneData` resource represents a directed centerline in world-space metres. The lane ID is unique and nonnegative; the centerline must have at least two finite points, no duplicate consecutive vertices, and nonzero length. Width and speed limits are finite and positive. Vehicle bit masks encode Car=1, Bus=2, Bike=4, Emergency=8.

`CivicRoadGraph` stores lanes by stable ID and provides sorted iteration, lookup, validation and legal outgoing connections. Outgoing references must exist, be unique, not self-reference, and join within 2 metres. Normal legal lanes cannot connect directly to a wrong-way connector. Legal routing excludes wrong-way connectors and respects vehicle masks.

Graph insertion rejects duplicate and negative IDs, but **does not mutate or reject geometry**: run `validate()` after building or editing a graph. It returns a list of human-readable errors, allowing the editor to display all problems at once. Resource mutation after insertion requires revalidation.

A* lane routing, intersection priority and spatial indexing are separate follow-on issues (CC-007 onward).

## Run tests

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/lane_graph_test.gd
```
