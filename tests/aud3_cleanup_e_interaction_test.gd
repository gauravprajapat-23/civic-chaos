extends SceneTree
## AUD3-CLEANUP: E/USE must collect ground wrappers and deposit at the bin
## without requiring a precise center-screen ray or extra modal buttons.
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Cleanup = preload("res://scripts/civic/market_cleanup_mission.gd")

func _initialize() -> void:
    # The full game installs these in Main._enter_tree; isolated scene tests
    # need the same actions before any player physics callback occurs.
    for action in ["look_left", "look_right", "look_up", "look_down",
            "move_left", "move_right", "move_forward", "move_back",
            "sprint", "jump", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.collision_layer = 1
    floor.position.y = -0.25
    var floor_shape := CollisionShape3D.new()
    floor_shape.name = "CollisionShape3D"
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(120, 0.5, 120)
    floor_shape.shape = floor_box
    floor.add_child(floor_shape)
    stage.add_child(floor)
    var player := PlayerScene.instantiate() as CivicPlayerController
    stage.add_child(player)
    player.set_physics_process(false)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("session unavailable")
        return
    var cleanup := Cleanup.new() as CivicMarketCleanupMission
    stage.add_child(cleanup)
    if not cleanup.configure(stage, player, civic):
        _fail("mission not configured")
        return

    var wrapper: CivicCleanupTarget = cleanup.targets[0]
    player.global_position = wrapper.global_position + Vector3(0, 0, 1.6)
    await physics_frame
    if player._nearby_cleanup_target() != wrapper:
        _fail("camera-facing ground wrapper not discoverable with E")
        return
    player.try_interact()
    if not cleanup.inspected or cleanup.carried_index != 0 or wrapper.visible:
        _fail("one E press did not record evidence and collect the wrapper")
        return
    if int(civic.missions.missions[Cleanup.MISSION_ID]["progress"]["litter_evidence"]) != 1:
        _fail("pickup did not record inspection exactly once")
        return
    player.global_position = cleanup.market_bin.global_position + Vector3(0, 0, 1.6)
    await physics_frame
    if player._nearby_cleanup_target() != cleanup.market_bin:
        _fail("nearby green bin not discoverable with E")
        return
    player.try_interact()
    if cleanup.carried_index != -1 or cleanup.bin_fill != 1 or cleanup.deposited_count != 1:
        _fail("E at bin did not deposit carried wrapper")
        return
    if not Cleanup.checkpoint_valid(cleanup.snapshot(), civic.snapshot()):
        _fail("direct E pickup/deposit left invalid checkpoint")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_AUD3_CLEANUP_E_INTERACTION_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
