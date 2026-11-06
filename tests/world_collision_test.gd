extends SceneTree

const Walkers = preload("res://scripts/npc/district_pedestrians.gd")
const Furniture = preload("res://scripts/world/street_furniture.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var walkers := Walkers.new()
    root.add_child(walkers)
    if walkers.get_child_count() != walkers.pedestrian_count:
        _fail(walkers, "pedestrian count mismatch")
        return
    for walker in walkers.get_children():
        if not walker is AnimatableBody3D or walker.collision_layer != 8:
            _fail(walkers, "pedestrian body or layer missing")
            return
        if walker.get_node_or_null("BodyCollision") == null:
            _fail(walkers, "pedestrian capsule missing")
            return
    var furniture := Furniture.new()
    root.add_child(furniture)
    for prop in furniture.get_children():
        if not prop is StaticBody3D or prop.get_child_count() == 0:
            furniture.free()
            _fail(walkers, "street prop is not solid")
            return
        var has_shape := false
        for child in prop.get_children():
            if child is CollisionShape3D:
                has_shape = true
        if not has_shape:
            furniture.free()
            _fail(walkers, "street prop collision shape missing")
            return
    furniture.free()
    walkers.free()
    print("CIVIC_CHAOS_WORLD_COLLISION_PASS")
    quit(0)

func _fail(node: Node, message: String) -> void:
    push_error(message)
    node.free()
    quit(1)
