extends SceneTree
## Render visibility regression for actual procedural district buildings.
## Building shells must not disappear when their decorative details remain.
const Neighborhood = preload("res://scripts/world/neighborhood.gd")
const LOD = preload("res://scripts/rendering/graphics_lod.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var camera := Camera3D.new()
    stage.add_child(camera)
    var district := Neighborhood.new()
    district.name = "Neighborhood"
    stage.add_child(district)
    var controller := LOD.new()
    stage.add_child(controller)
    if not controller.configure(camera, LOD.Quality.HIGH):
        _fail("LOD configuration rejected")
        return
    var shells: Array[MeshInstance3D] = []
    for mesh in get_nodes_in_group("lod_meshes"):
        if mesh is MeshInstance3D and district.is_ancestor_of(mesh):
            if not controller.register_mesh(mesh):
                _fail("building mesh registration failed")
                return
            shells.append(mesh)
    if shells.size() < 10:
        _fail("insufficient procedural buildings in integration test: %d" % shells.size())
        return
    for quality in [LOD.Quality.LOW, LOD.Quality.HIGH]:
        if not controller.configure(camera, quality):
            _fail("LOD quality change failed")
            return
        for position in [Vector3(0.0, 12.0, 0.0), Vector3(300.0, 20.0, 300.0), Vector3(-450.0, 30.0, -450.0)]:
            camera.global_position = position
            controller.update_lod()
            for shell in shells:
                if not shell.visible:
                    _fail("building shell disappeared at %s, quality %d" % [str(position), quality])
                    return
                var building: Node3D = shell.get_parent() as Node3D
                var roof: MeshInstance3D = building.get_node_or_null("RoofTrim") as MeshInstance3D
                var window: MeshInstance3D = building.get_node_or_null("WindowFront_0_0") as MeshInstance3D
                if roof == null or window == null or not roof.visible or not window.visible:
                    _fail("building facade/roof details missing at distance")
                    return
    stage.queue_free()
    print("CIVIC_CHAOS_BUILDING_DISTANCE_LOD_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
