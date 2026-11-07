extends SceneTree
## GAME-016 — a real car physically stops a walking witness, the owner moves
## only after inspection/request, and actual walking-path recovery pays once.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Parking = preload("res://scripts/civic/illegal_parking_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _world() -> Node3D:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.name = "TerrainGround"
    floor.collision_layer = 1
    floor.collision_mask = 0
    floor.position = Vector3(0, -0.25, 0)
    var collider := CollisionShape3D.new()
    collider.name = "CollisionShape3D"
    var shape := BoxShape3D.new()
    shape.size = Vector3(150, 0.5, 100)
    collider.shape = shape
    floor.add_child(collider)
    stage.add_child(floor)
    return stage

func _run() -> void:
    var stage := _world()
    var player := Node3D.new()
    player.name = "PlayerRoot"
    player.position = Vector3(80, 0, -5)
    stage.add_child(player)
    var civic := Session.new()
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic session could not initialize")
        return
    var parking := Parking.new()
    stage.add_child(parking)
    if not parking.configure(stage, player, civic):
        _fail("illegal parking could not stage")
        return
    var car_body := parking.parked_vehicle.get_node_or_null("CollisionBody") as CollisionObject3D
    if car_body == null or car_body.collision_layer != 4:
        _fail("parked car is not physical world traffic geometry")
        return
    if parking.perform_incident_action(player, "request_owner"):
        _fail("far-away owner request was accepted")
        return
    var card_events: Array[Dictionary] = []
    parking.incident_card_requested.connect(func(info: Dictionary) -> void:
        card_events.append(info)
    )
    parking.owner.interact(player)
    if not card_events.is_empty():
        _fail("distant owner interaction opened card")
        return
    player.position = parking.owner.position + Vector3(0, 0, 1.8)
    if parking.perform_incident_action(player, "inspect"):
        _fail("inspection accepted before real pedestrian was blocked")
        return
    var blocked: bool = false
    for frame in range(370):
        await physics_frame
        if parking.observed_blockage:
            blocked = true
            break
    if not blocked or parking.blocking_frames < Parking.BLOCKED_FRAMES_REQUIRED:
        _fail("real pedestrian did not physically stop at the orange car")
        return
    if parking.witness.position.x < Parking.WALK_START.x + 0.5 or parking.witness.position.x >= Parking.CLEARANCE_X:
        _fail("pedestrian moved through obstruction or never approached it")
        return
    if not parking._path_blocked_by_parked_car(parking.witness.position,
        parking.witness.position + Vector3(0.12, 0, 0)):
        _fail("witness was not actually stopped by parked car's collider")
        return
    parking.owner.interact(player)
    if card_events.size() != 1 or not card_events[0]["can_inspect"]:
        _fail("nearby owner did not offer evidence inspection")
        return
    if parking.perform_incident_action(player, "request_owner"):
        _fail("uninspected owner request accepted")
        return
    if not parking.perform_incident_action(player, "inspect"):
        _fail("evidence inspection denied")
        return
    if parking.perform_incident_action(player, "inspect"):
        _fail("duplicate evidence inspection allowed")
        return
    if not parking.perform_incident_action(player, "request_owner"):
        _fail("cooperative owner request denied")
        return
    if parking.perform_incident_action(player, "request_owner"):
        _fail("duplicate owner request allowed")
        return
    if not parking.owner_agreed or parking.intervention_tick >= 0:
        _fail("owner teleported to vehicle or failed to agree")
        return
    if parking.parked_vehicle.position.distance_to(Parking.VEHICLE_START) > 0.01:
        _fail("parked car moved before the owner arrived")
        return
    var last_position: Vector3 = parking.parked_vehicle.position
    var observed_movement: bool = false
    var resolved: bool = false
    var max_car_step: float = Parking.CAR_SPEED / float(Engine.physics_ticks_per_second) + 0.08
    for frame in range(1300):
        await physics_frame
        var next_position: Vector3 = parking.parked_vehicle.position
        var moved: float = next_position.distance_to(last_position)
        if moved > max_car_step:
            _fail("relocation teleported %.2f metres in one physics frame" % moved)
            return
        if moved > 0.001:
            observed_movement = true
        last_position = next_position
        if parking.finished:
            resolved = true
            break
    if not observed_movement or not resolved:
        _fail("owner relocation or real pedestrian path recovery did not finish")
        return
    if parking.parked_vehicle.position.distance_to(Parking.PARKING_BAY) > 0.05:
        _fail("vehicle did not reach its marked relocation bay")
        return
    if not parking.pedestrian_recovered or parking.witness.position.x < Parking.CLEARANCE_X:
        _fail("mission completed without witness passing the former obstruction")
        return
    if civic.incidents.incidents[parking.incident_id]["state"] != CivicIncidentManager.RESOLVED:
        _fail("parking incident was not physically resolved")
        return
    if civic.missions.missions[Parking.MISSION_ID]["state"] != CivicMissionManager.COMPLETED:
        _fail("parking mission objectives were not completed")
        return
    if civic.metrics.scores["trust"] != 520 or civic.metrics.scores["safety"] != 515:
        _fail("actual recovery did not apply one civic outcome")
        return
    if civic.missions.claim_reward(Parking.MISSION_ID) != 0:
        _fail("parking reward could be claimed a second time")
        return
    if not is_instance_valid(parking.parked_vehicle):
        _fail("relocated car collider was deleted rather than parked in the bay")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_ILLEGAL_PARKING_LIVE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
