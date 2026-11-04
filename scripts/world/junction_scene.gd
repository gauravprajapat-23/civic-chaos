extends Node3D
## Reusable four-way visual junction; graph is built from the same endpoints.

const Builder = preload("res://scripts/world/junction_builder.gd")

var road_graph: CivicRoadGraph

func _ready() -> void:
    road_graph = Builder.make_test_graph()
    Builder.make_road_visuals(self)
    var errors := road_graph.validate()
    if not errors.is_empty():
        push_error("Junction graph invalid: %s" % str(errors))
