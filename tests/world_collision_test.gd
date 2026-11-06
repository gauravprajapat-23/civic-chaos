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
    var counts := {"TrafficSignal": 0, "Streetlight": 0, "Tree": 0, "TrashBin": 0, "SidewalkBench": 0}
    for prop in furniture.get_children():
        if not prop is StaticBody3D:
            furniture.free()
            _fail(walkers, "street prop is not StaticBody3D: " + prop.name)
            return
        var body := prop as StaticBody3D
        if body.collision_layer != 1 or body.collision_mask != 0:
            furniture.free()
            _fail(walkers, "incorrect collision layers: " + prop.name)
            return
        var shape_count: int = 0
        for child in prop.get_children():
            if child is CollisionShape3D:
                var collider := child as CollisionShape3D
                if collider.shape == null or collider.disabled or not collider.shape is BoxShape3D:
                    furniture.free()
                    _fail(walkers, "invalid street prop collider: " + prop.name)
                    return
                var box := collider.shape as BoxShape3D
                if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
                    furniture.free()
                    _fail(walkers, "empty street prop collider: " + prop.name)
                    return
                shape_count += 1
        if shape_count != 1:
            furniture.free()
            _fail(walkers, "expected exactly one collision shape: " + prop.name)
            return
        var kind := ""
        for prefix in counts.keys():
            if prop.name.begins_with(str(prefix)):
                kind = str(prefix)
                break
        if kind.is_empty():
            furniture.free()
            _fail(walkers, "unknown street prop: " + prop.name)
            return
        counts[kind] += 1
    var expected := {"TrafficSignal": 4, "Streetlight": 8, "Tree": 8, "TrashBin": 2, "SidewalkBench": 2}
    if counts != expected:
        furniture.free()
        _fail(walkers, "unexpected furniture count: " + str(counts))
        return
    furniture.free()
    walkers.free()
    print("CIVIC_CHAOS_WORLD_COLLISION_PASS")
    quit(0)

func _fail(node: Node, message: String) -> void:
    push_error(message)
    node.free()
    quit(1)
