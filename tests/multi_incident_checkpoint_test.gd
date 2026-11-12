extends SceneTree
## GAME-017 — Campaign checkpoint: completed wrong-way civic incident and an
## actively relocating parked vehicle must survive one shared JSON restart.
const Builder = preload("res://scripts/world/junction_builder.gd")
const Session = preload("res://scripts/civic/gameplay_session.gd")
const WrongWay = preload("res://scripts/civic/wrong_way_live_mission.gd")
const Parking = preload("res://scripts/civic/illegal_parking_mission.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")
const SAVE_PATH: String = "user://game017_multi_incident_test.json"

func _initialize() -> void:
    call_deferred("_run")

func _stage() -> Node3D:
    var scene := Node3D.new()
    root.add_child(scene)
    var floor := StaticBody3D.new()
    floor.name = "TerrainGround"
    floor.position = Vector3(0, -0.25, 0)
    floor.collision_layer = 1
    floor.collision_mask = 0
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    var slab := BoxShape3D.new()
    slab.size = Vector3(180, 0.5, 100)
    shape.shape = slab
    floor.add_child(shape)
    scene.add_child(floor)
    return scene

func _run() -> void:
    _cleanup_save()
    var graph: CivicRoadGraph = Builder.make_city_graph()
    var first := _stage()
    var player := Node3D.new()
    player.position = Vector3(15, 0, 15)
    first.add_child(player)
    var civic := Session.new() as CivicGameplaySession
    first.add_child(civic)
    if not civic.configure(first, player):
        _fail("civic session failed")
        return
    var traffic := WrongWay.new() as CivicWrongWayLiveMission
    first.add_child(traffic)
    if not traffic.configure(first, player, graph, civic):
        _fail("could not stage wrong-way physical traffic")
        return
    for frame in range(620):
        await physics_frame
        if traffic.stopped_count >= WrongWay.REQUIRED_STOPPED:
            break
    if traffic.stopped_count < WrongWay.REQUIRED_STOPPED:
        _fail("wrong-way traffic queue not observed")
        return
    player.position = traffic.marker.position + Vector3(0, 0, 1.8)
    if not traffic.perform_incident_action(player, "inspect") or not traffic.perform_incident_action(player, "report"):
        _fail("wrong-way report not authorized")
        return
    for frame in range(1300):
        await physics_frame
        if traffic.finished:
            break
    if not traffic.finished:
        _fail("wrong-way traffic did not physically recover")
        return
    var old_wrong: Dictionary = traffic.snapshot()
    if not WrongWay.checkpoint_valid(old_wrong, graph, civic.snapshot()):
        _fail("completed wrong-way checkpoint not valid before parking")
        return

    var parking := Parking.new() as CivicIllegalParkingMission
    first.add_child(parking)
    if not parking.configure(first, player, civic):
        _fail("physical parking witness failed to stage after traffic recovery")
        return
    player.position = parking.parking_owner.position + Vector3(0, 0, 1.8)
    for frame in range(430):
        await physics_frame
        if parking.observed_blockage:
            break
    if not parking.observed_blockage:
        _fail("real parking witness did not encounter obstruction")
        return
    if not parking.perform_incident_action(player, "inspect") or not parking.perform_incident_action(player, "request_owner"):
        _fail("parking owner did not accept valid request")
        return
    for frame in range(500):
        await physics_frame
        if parking._car_route_progress_m > 0.7:
            break
    if parking._car_route_progress_m <= 0.7 or parking.finished:
        _fail("could not reach mid-relocation checkpoint phase")
        return
    var civic_snapshot: Dictionary = civic.snapshot()
    var wrong_snapshot: Dictionary = traffic.snapshot()
    var parking_snapshot: Dictionary = parking.snapshot()
    var reasons: Array = []
    if not civic.can_restore(civic_snapshot) or not WrongWay.checkpoint_valid(wrong_snapshot, graph, civic_snapshot, reasons):
        _fail("completed wrong-way incident became invalid after newer parking activity: " + str(reasons))
        return
    if not Parking.checkpoint_valid(parking_snapshot, civic_snapshot, reasons):
        _fail("parking checkpoint failed shared-manager verification: " + str(reasons))
        return
    if not SaveRepo.write_save({
        "player": {"x": player.position.x, "y": 0.0, "z": player.position.z, "yaw": 0.0},
        "civic_session": civic_snapshot,
        "wrong_way_checkpoint": wrong_snapshot,
        "parking_checkpoint": parking_snapshot
    }, SAVE_PATH):
        _fail("multi-incident checkpoint could not be saved atomically")
        return
    var loaded: Dictionary = SaveRepo.read_save(SAVE_PATH)
    if loaded.is_empty() or not WrongWay.checkpoint_valid(
        loaded.get("wrong_way_checkpoint"), graph, loaded.get("civic_session")) or not Parking.checkpoint_valid(
        loaded.get("parking_checkpoint"), loaded.get("civic_session")):
        _fail("campaign JSON invalid after disk round trip")
        return
    var original_count: int = civic.missions.missions.size()
    first.queue_free()
    await physics_frame
    await physics_frame

    var second := _stage()
    var next_player := Node3D.new()
    next_player.position = Parking.OWNER_START + Vector3(0, 0, 1.8)
    second.add_child(next_player)
    var restored_civic := Session.new() as CivicGameplaySession
    second.add_child(restored_civic)
    if not restored_civic.configure(second, next_player):
        _fail("new civic manager could not configure")
        return
    var restored_wrong := WrongWay.new() as CivicWrongWayLiveMission
    second.add_child(restored_wrong)
    if not restored_wrong.prepare_restore(second, next_player, graph, restored_civic):
        _fail("could not stage restored wrong-way actor group")
        return
    var restored_parking := Parking.new() as CivicIllegalParkingMission
    second.add_child(restored_parking)
    if not restored_parking.prepare_restore(second, next_player, restored_civic):
        _fail("could not stage parking group without duplicating an incident")
        return
    if not restored_civic.restore(loaded["civic_session"]):
        _fail("shared civic incident, score and mission history failed to restore")
        return
    if not restored_wrong.restore(loaded["wrong_way_checkpoint"]):
        _fail("completed wrong-way actors did not restore against later incident")
        return
    if not restored_parking.restore(loaded["parking_checkpoint"]):
        _fail("active parking actors did not restore beside completed traffic")
        return
    if restored_civic.missions.missions.size() != original_count:
        _fail("campaign restore registered an extra mission")
        return
    if restored_civic.missions.claim_reward(WrongWay.MISSION_ID) != 0 or restored_civic.missions.claim_reward(Parking.MISSION_ID) != 0:
        _fail("restored campaign duplicated old or unfinished rewards")
        return
    if not restored_wrong.finished or restored_parking.finished:
        _fail("restored mission phases are not independent")
        return
    for frame in range(1300):
        await physics_frame
        if restored_parking.finished:
            break
    if not restored_parking.finished:
        _fail("restored parking vehicle did not complete after real moving traffic")
        return
    if restored_civic.metrics.scores["safety"] != 535 or restored_civic.metrics.scores["trust"] != 520:
        _fail("campaign outcome was missing or applied twice")
        return
    if restored_civic.missions.claim_reward(Parking.MISSION_ID) != 0:
        _fail("completed parking campaign reward was duplicated")
        return
    reasons.clear()
    if not Parking.checkpoint_valid(restored_parking.snapshot(), restored_civic.snapshot(), reasons):
        _fail("completed multi-incident checkpoint rejected: " + str(reasons))
        return
    if not WrongWay.checkpoint_valid(restored_wrong.snapshot(), graph, restored_civic.snapshot(), reasons):
        _fail("earlier completed wrong-way checkpoint rejected after parking resolved")
        return
    second.queue_free()
    _cleanup_save()
    print("CIVIC_CHAOS_MULTI_INCIDENT_CHECKPOINT_PASS")
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
