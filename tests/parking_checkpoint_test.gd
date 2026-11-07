extends SceneTree
## GAME-017: an on-disk JSON checkpoint resumes real owner/car/witness actors.
## Also enforces the same once-only reward after the restored mission finishes.
const Session = preload("res://scripts/civic/gameplay_session.gd")
const Parking = preload("res://scripts/civic/illegal_parking_mission.gd")
const Cleanup = preload("res://scripts/civic/market_cleanup_mission.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")
const SAVE_PATH: String = "user://game017_parking_checkpoint_test.json"

func _initialize() -> void:
    call_deferred("_run")

func _world() -> Node3D:
    var stage := Node3D.new()
    root.add_child(stage)
    var ground := StaticBody3D.new()
    ground.name = "TerrainGround"
    ground.collision_layer = 1
    ground.collision_mask = 0
    ground.position = Vector3(0, -0.25, 0)
    var collider := CollisionShape3D.new()
    collider.name = "CollisionShape3D"
    var slab := BoxShape3D.new()
    slab.size = Vector3(150, 0.5, 100)
    collider.shape = slab
    ground.add_child(collider)
    stage.add_child(ground)
    return stage

func _document(civic: CivicGameplaySession, parking: CivicIllegalParkingMission, player: Node3D) -> Dictionary:
    return {
        "player": {
            "x": player.global_position.x, "y": player.global_position.y,
            "z": player.global_position.z, "yaw": player.rotation.y
        },
        "civic_session": civic.snapshot(),
        "parking_checkpoint": parking.snapshot()
    }

func _run() -> void:
    _cleanup_save()
    var stage := _world()
    var player := Node3D.new()
    player.position = Parking.OWNER_START + Vector3(0, 0, 1.8)
    stage.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    stage.add_child(civic)
    if not civic.configure(stage, player):
        _fail("civic manager did not configure")
        return
    var parking := Parking.new() as CivicIllegalParkingMission
    stage.add_child(parking)
    if not parking.configure(stage, player, civic):
        _fail("physical parking actors failed to stage")
        return

    var initial: Dictionary = parking.snapshot()
    if not Parking.checkpoint_valid(initial, civic.snapshot()):
        _fail("initial parking state rejected by checkpoint validator")
        return
    var forged: Dictionary = initial.duplicate(true)
    forged["schema_version"] = 999
    if Parking.checkpoint_valid(forged, civic.snapshot()):
        _fail("unsupported checkpoint version was accepted")
        return
    forged = initial.duplicate(true)
    forged["owner_agreed"] = true
    if Parking.checkpoint_valid(forged, civic.snapshot()):
        _fail("owner consent was forged without contact")
        return
    forged = initial.duplicate(true)
    forged["car_route_progress"] = 300
    if Parking.checkpoint_valid(forged, civic.snapshot()):
        _fail("out-of-bounds vehicle route progress was accepted")
        return

    for frame in range(410):
        await physics_frame
        if parking.observed_blockage:
            break
    if not parking.observed_blockage:
        _fail("physical witness never stopped at the parked car")
        return
    if not parking.perform_incident_action(player, "inspect") or not parking.perform_incident_action(player, "request_owner"):
        _fail("authorized parking incident could not be inspected and reported")
        return
    if not SaveRepo.write_save(_document(civic, parking, player), SAVE_PATH):
        _fail("reported parking checkpoint not written to disk")
        return
    var report_disk: Dictionary = SaveRepo.read_save(SAVE_PATH)
    if report_disk.is_empty() or not Parking.checkpoint_valid(
        report_disk.get("parking_checkpoint"), report_disk.get("civic_session")):
        _fail("reported parking checkpoint failed JSON round trip")
        return

    for frame in range(720):
        await physics_frame
        if parking.relocation_started and parking._car_route_progress_m > 1.0:
            break
    if not parking.relocation_started or parking._car_route_progress_m <= 1.0:
        _fail("physical owner and car did not begin moving")
        return
    var old_car_progress: float = parking._car_route_progress_m
    var old_owner_pos: Vector3 = parking.owner.global_position
    var old_witness_pos: Vector3 = parking.witness.global_position
    if not SaveRepo.write_save(_document(civic, parking, player), SAVE_PATH):
        _fail("moving car checkpoint failed to save")
        return
    var loaded: Dictionary = SaveRepo.read_save(SAVE_PATH)
    if loaded.is_empty() or not Parking.checkpoint_valid(
        loaded.get("parking_checkpoint"), loaded.get("civic_session")):
        _fail("moving car checkpoint was not JSON-safe")
        return
    if civic.missions.claim_reward(Parking.MISSION_ID) != 0:
        _fail("unfinished parking mission issued premature reward")
        return
    var original_mission_count: int = civic.missions.missions.size()
    stage.queue_free()
    await physics_frame
    await physics_frame

    var fresh := _world()
    var next_player := Node3D.new()
    next_player.position = player.position if is_instance_valid(player) else Parking.OWNER_START + Vector3(0, 0, 1.8)
    fresh.add_child(next_player)
    var next_civic := Session.new() as CivicGameplaySession
    fresh.add_child(next_civic)
    if not next_civic.configure(fresh, next_player):
        _fail("new civic manager did not configure")
        return
    var next_parking := Parking.new() as CivicIllegalParkingMission
    fresh.add_child(next_parking)
    if not next_parking.prepare_restore(fresh, next_player, next_civic):
        _fail("restaged parking actors were not physically safe")
        return
    if not next_civic.can_restore(loaded["civic_session"]) or not next_civic.restore(loaded["civic_session"]):
        _fail("saved civic history could not be reconstructed")
        return
    if not next_parking.restore(loaded["parking_checkpoint"]):
        _fail("saved car, owner or witness could not be restored")
        return
    if absf(next_parking._car_route_progress_m - old_car_progress) > 0.025:
        _fail("car lost relocation progress after JSON restart")
        return
    if next_parking.owner.global_position.distance_to(old_owner_pos) > 0.025:
        _fail("cooperating owner moved unexpectedly on resume")
        return
    if next_parking.witness.global_position.distance_to(old_witness_pos) > 0.025:
        _fail("witness progress was lost on resume")
        return
    if next_civic.missions.missions.size() != original_mission_count:
        _fail("mission was registered twice during actor restoration")
        return
    if next_parking.perform_incident_action(next_player, "request_owner"):
        _fail("owner request could be submitted twice after loading")
        return
    if next_civic.missions.claim_reward(Parking.MISSION_ID) != 0:
        _fail("reward could be claimed before restored pedestrian recovery")
        return

    for frame in range(1300):
        await physics_frame
        if next_parking.finished:
            break
    if not next_parking.finished or not next_parking.pedestrian_recovered:
        _fail("restored physical pedestrian path never recovered")
        return
    if next_parking.parked_vehicle.position.distance_to(Parking.PARKING_BAY) > 0.05:
        _fail("restored car never reached marked parking bay")
        return
    if next_civic.metrics.scores["trust"] != 520 or next_civic.metrics.scores["safety"] != 515:
        _fail("parking recovery metrics inconsistent or duplicated")
        return
    if next_civic.missions.claim_reward(Parking.MISSION_ID) != 0:
        _fail("completed parking mission reward could be claimed twice")
        return
    var final_checkpoint: Variant = JSON.parse_string(JSON.stringify(next_parking.snapshot()))
    var reason: Array = []
    if not Parking.checkpoint_valid(final_checkpoint, next_civic.snapshot(), reason):
        _fail("completed parking checkpoint invalid: " + str(reason))
        return
    forged = (final_checkpoint as Dictionary).duplicate(true)
    forged["finished"] = false
    if Parking.checkpoint_valid(forged, next_civic.snapshot()):
        _fail("forged incomplete outcome passed checkpoint validation")
        return
    forged = (final_checkpoint as Dictionary).duplicate(true)
    forged["pedestrian_recovered"] = false
    if Parking.checkpoint_valid(forged, next_civic.snapshot()):
        _fail("forged pedestrian recovery passed checkpoint validation")
        return
    # After the later market incident starts, the earlier completed
    # parking checkpoint retains its terminal tick and must remain valid.
    var cleanup := Cleanup.new() as CivicMarketCleanupMission
    fresh.add_child(cleanup)
    if not cleanup.configure(fresh, next_player, next_civic):
        _fail("later market cleanup could not start after completed parking")
        return
    for frame in range(8):
        await physics_frame
    reason.clear()
    if not Parking.checkpoint_valid(final_checkpoint, next_civic.snapshot(), reason):
        _fail("completed parking was rejected after a later incident: " + str(reason))
        return
    if not Cleanup.checkpoint_valid(cleanup.snapshot(), next_civic.snapshot()):
        _fail("later cleanup initial checkpoint is inconsistent")
        return
    fresh.queue_free()
    _cleanup_save()
    print("CIVIC_CHAOS_PARKING_CHECKPOINT_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    _cleanup_save()
    quit(1)

## A generation-2 checkpoint keeps backup and temporary siblings. Isolate
## each test so an earlier run cannot be mistaken for a valid recovery.
func _cleanup_save() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        var candidate: String = SAVE_PATH + suffix
        if FileAccess.file_exists(candidate):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
