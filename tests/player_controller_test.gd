extends SceneTree
## Headless structural and API smoke test for CC-004.

const PlayerScene = preload("res://scenes/player/player_root.tscn")
const MarkerScene = preload("res://scenes/world/interaction_marker.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var player := PlayerScene.instantiate()
    if not player is CharacterBody3D:
        push_error("Player root must be CharacterBody3D")
        quit(1)
        return
    if player.collision_mask != 1:
        push_error("Player must resolve vertical collision only against solid world surfaces")
        player.free()
        quit(1)
        return
    var arm := player.get_node_or_null("CameraPivot/SpringArm3D")
    var camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
    if not arm is SpringArm3D or not camera is Camera3D:
        push_error("Collision-aware camera hierarchy missing")
        player.free()
        quit(1)
        return
    if not player.has_method("rotate_camera") or not player.has_method("try_interact"):
        push_error("Player API missing")
        player.free()
        quit(1)
        return
    var marker := MarkerScene.instantiate()
    if not marker.has_method("interact"):
        push_error("Interaction target API missing")
        marker.free()
        player.free()
        quit(1)
        return
    marker.free()
    player.free()
    print("CIVIC_CHAOS_PLAYER_PASS")
    quit(0)
