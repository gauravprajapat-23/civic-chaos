extends SceneTree
const LOD = preload("res://scripts/rendering/graphics_lod.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root_node := Node3D.new()
    root.add_child(root_node)
    var camera := Camera3D.new()
    root_node.add_child(camera)
    var controller := LOD.new()
    root_node.add_child(controller)
    assert(controller.configure(camera, LOD.Quality.LOW))
    var high := MeshInstance3D.new()
    high.position = Vector3(0, 0, -12)
    root_node.add_child(high)
    var low := MeshInstance3D.new()
    low.position = high.position
    root_node.add_child(low)
    assert(controller.register_mesh(high, low))
    assert(not controller.register_mesh(high, low))
    controller.update_lod()
    assert(high.visible)
    assert(not low.visible)
    high.position = Vector3(0, 0, -30)
    low.position = high.position
    controller.update_lod()
    assert(not high.visible)
    assert(low.visible)
    high.position = Vector3(0, 0, -100)
    low.position = high.position
    controller.update_lod()
    if high.visible or not low.visible:
        _fail("distant mesh with a low-detail replacement must keep its proxy visible")
        return
    # Building shells are registered without a low-detail proxy in main.gd.
    # They must never be culled, including on mobile LOW quality.
    var building_shell := MeshInstance3D.new()
    building_shell.name = "BuildingShell"
    root_node.add_child(building_shell)
    assert(controller.register_mesh(building_shell))
    for selected_quality in [LOD.Quality.LOW, LOD.Quality.BALANCED, LOD.Quality.HIGH]:
        assert(controller.configure(camera, selected_quality))
        for distance in [12.0, 70.0, 140.0, 400.0]:
            building_shell.position = Vector3(0, 0, -distance)
            controller.update_lod()
            if not building_shell.visible:
                _fail("building without proxy disappeared at distance %s (quality %s)" % [distance, selected_quality])
                return
    assert(controller.configure(camera, LOD.Quality.LOW))
    var light := DirectionalLight3D.new()
    root_node.add_child(light)
    controller.apply_light_budget(root_node)
    assert(not light.shadow_enabled)
    root_node.queue_free()
    print("CIVIC_CHAOS_GRAPHICS_LOD_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
