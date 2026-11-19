extends SceneTree
## PROG-04: unlocked service uses the existing E/USE interaction layer.
const Service = preload("res://scripts/world/neighborhood_service.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var service := Service.new() as CivicNeighborhoodService
    service.setup(1, "E / USE | Community Service")
    stage.add_child(service)
    if service.collision_layer != 0 or service.collision_mask != 0:
        _fail("service was reachable before earning its project")
        return
    var player := Node3D.new()
    stage.add_child(player)
    var actions: Array[int] = []
    service.activated.connect(func(_actor: Node, index: int) -> void:
        actions.append(index)
    )
    service.interact(player)
    if not actions.is_empty():
        _fail("locked service emitted a civic action")
        return
    service.set_available(true)
    if service.collision_layer != 16 or service.collision_mask != 0:
        _fail("unlocked service does not use the interaction-only layer")
        return
    service.interact(player)
    if actions != [1]:
        _fail("earned service interaction did not emit expected project")
        return
    service.set_available(false)
    service.interact(player)
    if actions.size() != 1:
        _fail("relocked service emitted a duplicate civic action")
        return
    if service.get_node_or_null("InteractionShape") == null:
        _fail("neighborhood service has no ray-accessible collision shape")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_NEIGHBORHOOD_SERVICE_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
