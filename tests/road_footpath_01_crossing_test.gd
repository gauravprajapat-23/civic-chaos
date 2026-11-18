extends SceneTree
## ROAD-FOOTPATH-01: real neighborhood road-to-footpath travel for
## pedestrian and motorcycle. No teleporting, no disabled buildings.
const Neighborhood = preload("res://scripts/world/neighborhood.gd")
const PlayerScene = preload("res://scenes/player/player_root.tscn")
const Bike = preload("res://scripts/world/rideable_bike.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["move_forward", "move_back", "move_left", "move_right",
            "look_left", "look_right", "look_up", "look_down",
            "jump", "sprint", "interact"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    var stage := Node3D.new()
    root.add_child(stage)
    var district := Neighborhood.new() as CivicNeighborhood
    stage.add_child(district)
    await physics_frame

    # Real crossing between junctions: south-side road x <= 4, footpath
    # x 4..6, z=20 (outside intersection clearance intervals).
    var sidewalk := district.get_node_or_null("SidewalkX1_2") as StaticBody3D
    # Name-independent selection if the city layout has different spans.
    if sidewalk == null:
        for node in district.get_children():
            if node is StaticBody3D and node.name.begins_with("SidewalkX1_"):
                if absf(node.global_position.z - 20.0) < 20.0:
                    sidewalk = node
                    break
    if sidewalk == null:
        _fail("cannot locate neighborhood footpath near the south road")
        return
    var sidewalk_shape := sidewalk.get_node("CollisionShape3D") as CollisionShape3D
    var sidewalk_box := sidewalk_shape.shape as BoxShape3D
    var sidewalk_top: float = sidewalk.global_position.y + sidewalk_box.size.y * 0.5
    if absf(sidewalk_top - 0.035) > 0.002:
        _fail("physical footpath has a raised collision lip: y=%.3f" % sidewalk_top)
        return

    var walker := PlayerScene.instantiate() as CivicPlayerController
    walker.position = Vector3(3.0, 0.12, 20.0)
    stage.add_child(walker)
    await physics_frame
    walker.set_physics_process(false)
    for frame in range(80):
        walker.velocity = Vector3(2.3, -0.1, 0)
        walker.move_and_slide()
        await physics_frame
    if walker.global_position.x < 5.0:
        _fail("main character still blocked by footpath edge: x=%.3f" %
            walker.global_position.x)
        return
    walker.queue_free()
    await physics_frame

    var rider := PlayerScene.instantiate() as CivicPlayerController
    rider.position = Vector3(2.0, 0.15, 20.0)
    stage.add_child(rider)
    var bike := Bike.new() as CivicRideableBike
    bike.position = Vector3(3.0, 0.15, 20.0)
    bike.rotation.y = -PI * 0.5
    stage.add_child(bike)
    await physics_frame
    if not rider.mount_bike(bike):
        _fail("bike cannot mount next to clear footpath")
        return
    Input.action_press("move_forward")
    for frame in range(85):
        await physics_frame
    Input.action_release("move_forward")
    if rider.global_position.x < 5.2:
        _fail("bike still stuck at footpath crossing: x=%.3f speed=%.3f" %
            [rider.global_position.x, rider._bike_speed])
        return
    # Building collision remains intact: no allowing the motorcycle to
    # ghost into solid frontage after crossing a pedestrian walkway.
    var building := district.get_node_or_null("Building_1_1") as StaticBody3D
    if building == null or building.get_node_or_null("CollisionShape3D") == null:
        _fail("road-to-sidewalk fix removed building collision")
        return
    rider.set_physics_process(false)
    stage.queue_free()
    print("CIVIC_CHAOS_ROAD_FOOTPATH_01_CROSSING_PASS")
    quit(0)

func _fail(reason: String) -> void:
    Input.action_release("move_forward")
    push_error(reason)
    quit(1)
