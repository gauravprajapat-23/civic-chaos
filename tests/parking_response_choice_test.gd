extends SceneTree
## STORY-CHOICE-01: evidence-gated owner vs municipal choice, persistence and
## no early vehicle movement/reward while an official dispatch is pending.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Parking = preload("res://scripts/civic/illegal_parking_mission.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var stage := Node3D.new()
    root.add_child(stage)
    var floor := StaticBody3D.new()
    floor.collision_layer = 1
    floor.position = Vector3(0.0, -0.25, 0.0)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(150.0, 0.5, 100.0)
    collider.shape = shape
    floor.add_child(collider)
    stage.add_child(floor)
    var player := Node3D.new()
    player.position = Parking.OWNER_START + Vector3(0, 0, 1.8)
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic session rejected parking test")
        return
    var parking := Parking.new() as CivicIllegalParkingMission
    stage.add_child(parking)
    if not parking.configure(stage, player, civic):
        _fail("parking fixture failed to stage")
        return
    if parking.perform_incident_action(player, "request_service"):
        _fail("municipal assistance accepted without verified evidence")
        return
    for frame in range(420):
        await physics_frame
        if parking.observed_blockage:
            break
    if not parking.observed_blockage:
        _fail("witness never reached parked obstruction")
        return
    if not parking.perform_incident_action(player, "inspect"):
        _fail("real witnessed obstruction could not be inspected")
        return
    var choices: Dictionary = parking.incident_card_state()
    if choices.get("report_action") != "request_owner" or choices.get("alternative_action") != "request_service":
        _fail("parking card did not present two typed actions")
        return
    if not choices.get("can_report", false) or not choices.get("can_alternative", false):
        _fail("verified evidence did not unlock both safe responses")
        return
    if not parking.perform_incident_action(player, "request_service"):
        _fail("municipal service choice was rejected")
        return
    if parking.response_kind != "request_service" or parking.perform_incident_action(player, "request_owner"):
        _fail("player choice could be replaced or submitted twice")
        return
    var saved: Dictionary = parking.snapshot()
    if not Parking.checkpoint_valid(saved, civic.snapshot()):
        _fail("municipal choice failed checkpoint validation")
        return
    var json: Variant = JSON.parse_string(JSON.stringify(saved))
    if not Parking.checkpoint_valid(json, civic.snapshot()) or json["response_kind"] != "request_service":
        _fail("municipal choice did not survive JSON")
        return
    var forged: Dictionary = saved.duplicate(true)
    forged["response_kind"] = "seize_vehicle"
    if Parking.checkpoint_valid(forged, civic.snapshot()):
        _fail("unknown forceful response entered a valid checkpoint")
        return
    # Legacy owner checkpoints omit the new optional field.
    var legacy: Dictionary = saved.duplicate(true)
    legacy.erase("response_kind")
    if not Parking.checkpoint_valid(legacy, civic.snapshot()):
        _fail("legacy owner-route snapshots became incompatible")
        return
    var original_car_position: Vector3 = parking.parked_vehicle.global_position
    for frame in range(Parking.SERVICE_RESPONSE_TICKS - 2):
        await physics_frame
    if parking.parked_vehicle.global_position.distance_to(original_car_position) > 0.001:
        _fail("municipal dispatch moved the parked car before authorization")
        return
    if parking.intervention_tick >= 0 or parking.finished:
        _fail("municipal response awarded completion before physical recovery")
        return
    if civic.missions.claim_reward(Parking.MISSION_ID) != 0:
        _fail("municipal path granted premature mission points")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_PARKING_RESPONSE_CHOICE_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
