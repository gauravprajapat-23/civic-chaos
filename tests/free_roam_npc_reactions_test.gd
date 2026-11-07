extends SceneTree
## GAME-024: real pedestrian speech and gesture, without touching civic score or navigation.
const Pedestrians = preload("res://scripts/npc/district_pedestrians.gd")
const Challenges = preload("res://scripts/civic/free_roam_challenges.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var walkers: Node3D = Pedestrians.new()
    stage.add_child(walkers)
    if walkers._walkers.is_empty():
        _fail("no pedestrians in neighborhood")
        return
    var speaker: Node3D = walkers._walkers[0]["root"]
    var position_value: Vector3 = speaker.global_position
    walkers.react_to_incident(position_value, Challenges.CONE, "spawned", 1)
    if not is_instance_valid(walkers._reaction_label) or not walkers._reaction_label.visible:
        _fail("nearby pedestrian did not show civic speech")
        return
    if walkers._reaction_label.get_parent() != speaker or walkers._reaction_label.text.is_empty():
        _fail("witness reaction did not attach to a real walking NPC")
        return
    if walkers._reaction_context.is_empty():
        _fail("witness did not remember the live civic incident")
        return
    walkers.react_to_incident(position_value, Challenges.CONE, "resolved", 1)
    if not walkers._reaction_context.is_empty() or not walkers._reaction_label.text.contains("safer"):
        _fail("NPC did not acknowledge a completed challenge")
        return
    for frame in range(18):
        walkers._physics_process(0.25)
    if walkers._reaction_label.visible:
        _fail("speech bubble never expired")
        return
    walkers.react_to_incident(position_value, "not_real", "spawned", 1)
    if not walkers._reaction_context.is_empty():
        _fail("unrecognized event created a fake reaction")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_FREE_ROAM_NPC_REACTIONS_PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
