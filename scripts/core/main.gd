extends Node3D
## Walking prototype entry point and lifecycle controls.

@onready var status_label: Label = $CanvasLayer/HUD/VBoxContainer/Status
@onready var player: CivicPlayerController = $PlayerRoot
@onready var lifecycle: CivicGameLifecycle = $GameLifecycle
@onready var pause_panel: Control = $CanvasLayer/PausePanel
const StatusHUD = preload("res://scripts/ui/civic_status_hud.gd")
const DebugOverlay = preload("res://scripts/debug/debug_overlay.gd")
const GraphicsLOD = preload("res://scripts/rendering/graphics_lod.gd")
const DistrictPedestrians = preload("res://scripts/npc/district_pedestrians.gd")
const StreetFurniture = preload("res://scripts/world/street_furniture.gd")
const GameplaySession = preload("res://scripts/civic/gameplay_session.gd")
const WrongWayLiveMission = preload("res://scripts/civic/wrong_way_live_mission.gd")
const ParkingMission = preload("res://scripts/civic/illegal_parking_mission.gd")
const CleanupMission = preload("res://scripts/civic/market_cleanup_mission.gd")
const DistrictCampaign = preload("res://scripts/civic/district_campaign.gd")
const DistrictFinale = preload("res://scripts/ui/district_finale.gd")
const FreeRoamEvents = preload("res://scripts/civic/free_roam_events.gd")
const IncidentCard = preload("res://scripts/ui/civic_incident_card.gd")
const MissionGuide = preload("res://scripts/ui/civic_mission_guide.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")
const CheckpointTransaction = preload("res://scripts/core/checkpoint_transaction.gd")
const CheckpointLoadQueue = preload("res://scripts/core/checkpoint_load_queue.gd")
var graphics_lod: CivicGraphicsLOD
var debug_overlay: CivicDebugOverlay
var civic_hud: CivicStatusHUD
var gameplay_session: CivicGameplaySession
var wrong_way_world: CivicWrongWayLiveMission
var parking_world: CivicIllegalParkingMission
var cleanup_world: CivicMarketCleanupMission
var district_finale: CivicDistrictFinale
var free_roam_world: CivicFreeRoamEvents
var free_roam_unlocked: bool = false
var _finale_acknowledged: bool = false
var _card_source: Node
var incident_card: CivicIncidentDetailCard
var mission_guide: CivicMissionGuide
var touch_layer: CanvasLayer
var _traffic_display_elapsed: float = 0.0
var _wrong_way_retry_elapsed: float = 0.0
var _checkpoint_load_queue: CivicCheckpointLoadQueue = CheckpointLoadQueue.new()

func _enter_tree() -> void:
    _bind_key("move_forward", KEY_W)
    _bind_key("move_back", KEY_S)
    _bind_key("move_left", KEY_A)
    _bind_key("move_right", KEY_D)
    _bind_key("sprint", KEY_SHIFT)
    _bind_key("jump", KEY_SPACE)
    _bind_key("interact", KEY_E)
    _bind_key("pause_game", KEY_F1)
    _bind_key("district_results", KEY_F2)
    _bind_key("save_game", KEY_F5)
    _bind_key("load_game", KEY_F9)
    _bind_key("restart_game", KEY_F10)
    _bind_key("return_to_menu", KEY_F12)
    _bind_key("toggle_ai_debug", KEY_F3)
    _bind_key("export_ai_debug", KEY_F4)
    for action in ["look_left", "look_right", "look_up", "look_down"]:
        if not InputMap.has_action(action):
            InputMap.add_action(action)

func _bind_key(action: StringName, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var event := InputEventKey.new()
    event.physical_keycode = keycode
    if not InputMap.action_has_event(action, event):
        InputMap.action_add_event(action, event)

func _ready() -> void:
    player.interaction_message.connect(_on_interaction_message)
    lifecycle.lifecycle_message.connect(_on_interaction_message)
    status_label.text = "F1 pause | F5 save | F9 load | F10 restart | F12 menu"
    civic_hud = StatusHUD.new()
    civic_hud.name = "CivicStatusHUD"
    $CanvasLayer.add_child(civic_hud)
    civic_hud.render_state({"feedback": "Explore district | E interact"})
    var touch_script: Script = load("res://scripts/ui/touch_controls.gd") as Script
    if touch_script == null:
        push_error("Touch controls script failed to load")
        return
    touch_layer = touch_script.new() as CanvasLayer
    touch_layer.name = "TouchControls"
    add_child(touch_layer)
    debug_overlay = DebugOverlay.new()
    debug_overlay.name = "AIDebugOverlay"
    add_child(debug_overlay)
    graphics_lod = GraphicsLOD.new()
    graphics_lod.name = "GraphicsLOD"
    add_child(graphics_lod)
    graphics_lod.configure(player.camera, CivicGraphicsLOD.Quality.LOW if OS.has_feature("mobile") else CivicGraphicsLOD.Quality.HIGH)
    for mesh in get_tree().get_nodes_in_group("lod_meshes"):
        if mesh is MeshInstance3D:
            graphics_lod.register_mesh(mesh)
    graphics_lod.apply_light_budget(self)
    var pedestrians := DistrictPedestrians.new()
    pedestrians.name = "DistrictPedestrians"
    add_child(pedestrians)
    var junction: Node = get_node_or_null("FourWayJunction")
    if junction != null:
        var signals: CivicTrafficSignalController = junction.get("traffic_signals") as CivicTrafficSignalController
        var spawner: CivicTrafficSpawner = junction.get("traffic_spawner") as CivicTrafficSpawner
        var reservations: CivicIntersectionReservations = junction.get("intersection_reservations") as CivicIntersectionReservations
        if signals != null:
            pedestrians.configure_traffic(signals, spawner, reservations)
    var furniture := StreetFurniture.new()
    furniture.name = "StreetFurniture"
    add_child(furniture)
    if junction != null:
        var live_signals: CivicTrafficSignalController = junction.get("traffic_signals") as CivicTrafficSignalController
        if live_signals != null:
            furniture.configure_signals(live_signals)
    gameplay_session = GameplaySession.new() as CivicGameplaySession
    gameplay_session.name = "CivicGameplaySession"
    gameplay_session.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(gameplay_session)
    if not gameplay_session.configure(self, player, civic_hud):
        push_error("Civic gameplay session could not start")
    else:
        gameplay_session.feedback_changed.connect(_on_interaction_message)
        gameplay_session.incident_card_requested.connect(_on_incident_card_requested)
        gameplay_session.tutorial_completed.connect(_on_footpath_tutorial_completed)
    incident_card = IncidentCard.new() as CivicIncidentDetailCard
    incident_card.name = "CivicIncidentCard"
    add_child(incident_card)
    incident_card.action_selected.connect(_on_incident_card_action)
    incident_card.dismissed.connect(_on_incident_card_dismissed)
    mission_guide = MissionGuide.new() as CivicMissionGuide
    mission_guide.name = "CivicMissionGuide"
    add_child(mission_guide)
    mission_guide.recovery_action_requested.connect(_on_mission_recovery_action)
    district_finale = DistrictFinale.new() as CivicDistrictFinale
    district_finale.name = "DistrictFinale"
    add_child(district_finale)
    district_finale.continue_selected.connect(_on_finale_continue)
    district_finale.replay_selected.connect(_on_finale_replay)
    district_finale.review_selected.connect(_present_campaign_finale)
    _refresh_mission_guide()
    print("CIVIC_CHAOS_MAIN_READY")

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo or (district_finale != null and district_finale.is_open()):
        return
    if event.is_action_pressed("district_results"):
        if free_roam_unlocked and not get_tree().paused:
            _present_campaign_finale()
            get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("toggle_ai_debug"):
        debug_overlay.set_enabled(not debug_overlay.enabled)
    elif event.is_action_pressed("export_ai_debug"):
        _on_interaction_message("AI telemetry exported" if debug_overlay.export_snapshot() else "AI telemetry export failed")
    elif event.is_action_pressed("pause_game"):
        _toggle_pause()
    elif event.is_action_pressed("save_game"):
        _save_gameplay_checkpoint()
    elif event.is_action_pressed("load_game"):
        if incident_card != null and incident_card.is_open():
            incident_card.dismiss()
        _queue_gameplay_checkpoint_load()
    elif event.is_action_pressed("restart_game"):
        lifecycle.restart_game()
    elif event.is_action_pressed("return_to_menu"):
        lifecycle.return_to_menu()

## Input and guide callbacks are not guaranteed to run with an unlocked
## PhysicsDirectSpaceState3D. Snapshot the document once at request time,
## then stage cars/walkers only on this node's next physics tick.
func _queue_gameplay_checkpoint_load() -> bool:
    if _checkpoint_load_queue.has_pending():
        _on_interaction_message("A checkpoint load is already queued.")
        return false
    var chosen: Dictionary = SaveRepo.read_save_detail()
    if not _checkpoint_load_queue.request(chosen):
        return false
    _on_interaction_message("Checking checkpoint on the next physics tick...")
    return true

func _physics_process(_delta: float) -> void:
    if not _checkpoint_load_queue.has_pending():
        return
    var chosen: Dictionary = _checkpoint_load_queue.consume()
    _load_gameplay_checkpoint(chosen)

## GAME-014: F5/F9 saves one coherent player+civic+wrong-way document.
## Restore is preflighted before the live game world is changed.
func _save_gameplay_checkpoint() -> bool:
    if gameplay_session == null:
        return false
    var civic: Dictionary = gameplay_session.snapshot()
    var payload: Dictionary = {"civic_session": civic}
    if is_instance_valid(wrong_way_world):
        var live_state: Dictionary = wrong_way_world.snapshot()
        var junction: Node = get_node_or_null("FourWayJunction")
        var graph: CivicRoadGraph = null
        if junction != null:
            graph = junction.get("road_graph") as CivicRoadGraph
        if not CivicWrongWayLiveMission.checkpoint_valid(live_state, graph, civic):
            _on_interaction_message("Checkpoint rejected: incomplete wrong-way mission state")
            return false
        payload["wrong_way_checkpoint"] = live_state
    if is_instance_valid(parking_world):
        if not is_instance_valid(wrong_way_world) or not wrong_way_world.finished:
            _on_interaction_message("Parking save rejected: previous traffic incident not completed")
            return false
        var parking_state: Dictionary = parking_world.snapshot()
        var reasons: Array = []
        if not CivicIllegalParkingMission.checkpoint_valid(parking_state, civic, reasons):
            _on_interaction_message("Parking save rejected: %s" % str(reasons))
            return false
        payload["parking_checkpoint"] = parking_state
    if is_instance_valid(cleanup_world):
        if not is_instance_valid(parking_world) or not parking_world.finished:
            _on_interaction_message("Cleanup save rejected: parking mission is incomplete")
            return false
        var cleanup_state: Dictionary = cleanup_world.snapshot()
        var cleanup_errors: Array = []
        if not CivicMarketCleanupMission.checkpoint_valid(cleanup_state, civic, cleanup_errors):
            _on_interaction_message("Cleanup save rejected: %s" % str(cleanup_errors))
            return false
        payload["cleanup_checkpoint"] = cleanup_state
        if cleanup_world.finished:
            if not _campaign_ready():
                _on_interaction_message("Finale save refused: campaign ledger is incomplete")
                return false
            payload["campaign_checkpoint"] = DistrictCampaign.checkpoint(_finale_acknowledged)
            if is_instance_valid(free_roam_world):
                var roaming: Dictionary = free_roam_world.checkpoint_state()
                if not CivicFreeRoamEvents.checkpoint_valid(roaming, civic):
                    _on_interaction_message("Free Roam save rejected: event state disagrees with civic ledger")
                    return false
                payload["free_roam_checkpoint"] = roaming
    # GAME-019: a generation includes the background world as well as civic
    # mission actors. Reject an incoherent background tick instead of storing
    # an apparently valid player file with incomplete world state.
    var city_junction: Node = get_node_or_null("FourWayJunction")
    var walkers: Node3D = get_node_or_null("DistrictPedestrians") as Node3D
    if city_junction == null or walkers == null:
        _on_interaction_message("Checkpoint refused: city simulation unavailable")
        return false
    var world_state: Dictionary = city_junction.call("checkpoint_state", walkers)
    if not bool(city_junction.call("checkpoint_valid", world_state, walkers)):
        _on_interaction_message("Checkpoint refused: unsafe or inconsistent traffic world state")
        return false
    payload["world_checkpoint"] = world_state
    return lifecycle.save_player(player, "", payload)

## Reject malformed but otherwise checksum-valid nested records before any
## branch reads `.get()` or passes data to mission/resource validators.
## A shape check is deliberately separate from stage-specific validation:
## legacy player-only saves may legitimately omit all these fields.
static func checkpoint_record_types_valid(saved: Dictionary) -> bool:
    for record in [
        "civic_session",
        "wrong_way_checkpoint",
        "parking_checkpoint",
        "cleanup_checkpoint",
        "campaign_checkpoint",
        "free_roam_checkpoint",
        "world_checkpoint"
    ]:
        if saved.has(record) and not (saved[record] is Dictionary):
            return false
    return true

## Legacy player-only saves are valid, but they cannot also contain orphaned
## civic, campaign, traffic or Free Roam records. Such fields would otherwise
## be silently skipped by the no-civic-session early return in the loader.
static func checkpoint_envelope_valid(saved: Dictionary) -> bool:
    if not checkpoint_record_types_valid(saved):
        return false
    if saved.has("civic_session"):
        return true
    for record in [
        "wrong_way_checkpoint",
        "parking_checkpoint",
        "cleanup_checkpoint",
        "campaign_checkpoint",
        "free_roam_checkpoint",
        "world_checkpoint"
    ]:
        if saved.has(record):
            return false
    return true

## Null means "select latest from disk" for explicit legacy callers.
## An empty Dictionary is a completed selection of *no* checkpoint, not an
## instruction to reread. This protects the queued generation boundary even
## when a caller supplies an empty/unavailable selected document.
static func checkpoint_selected_document(selected: Variant = null) -> Dictionary:
    if selected == null:
        return SaveRepo.read_save_detail()
    if selected is Dictionary:
        return (selected as Dictionary).duplicate(true)
    return {}

func _load_gameplay_checkpoint(selected: Variant = null) -> bool:
    # F9 and mission-guide callers supply the already-read document. Never
    # select a newer file based on whether that document happens to be empty.
    var checkpoint: Dictionary = checkpoint_selected_document(selected)
    var saved: Dictionary = checkpoint.get("data", {})
    if saved.is_empty():
        _on_interaction_message("No valid checkpoint found")
        return false
    if not lifecycle.can_load_player_snapshot(player, saved):
        _on_interaction_message("Checkpoint rejected: player cannot safely accept this save")
        return false
    if not checkpoint_envelope_valid(saved):
        _on_interaction_message("Checkpoint rejected: malformed or orphaned save record")
        return false
    if str(checkpoint.get("source", "primary")) == "backup":
        _on_interaction_message("Primary checkpoint is invalid or missing. Recovering the verified backup.")
    if not saved.has("civic_session"):
        if is_instance_valid(wrong_way_world) or is_instance_valid(parking_world) or is_instance_valid(cleanup_world):
            _on_interaction_message("Old player-only save cannot replace an active civic incident")
            return false
        return lifecycle.load_player_snapshot(player, saved)
    var civic: Variant = saved["civic_session"]
    if gameplay_session == null or not gameplay_session.can_restore(civic):
        _on_interaction_message("Checkpoint rejected: invalid civic session")
        return false
    var has_live: bool = saved.has("wrong_way_checkpoint")
    var has_parking: bool = saved.has("parking_checkpoint")
    var has_cleanup: bool = saved.has("cleanup_checkpoint")
    var has_finale: bool = saved.has("campaign_checkpoint")
    var has_roam: bool = saved.has("free_roam_checkpoint")
    if has_roam and (not has_finale or not bool(saved["campaign_checkpoint"].get("finale_acknowledged", false))):
        _on_interaction_message("Checkpoint rejected: active Free Roam requires an acknowledged ending")
        return false
    if not has_roam and is_instance_valid(free_roam_world):
        _on_interaction_message("Checkpoint predates current Free Roam events. Restart level to load this earlier stage.")
        return false
    if has_finale and not has_cleanup:
        _on_interaction_message("Checkpoint rejected: Free Roam without completed cleanup")
        return false
    if has_cleanup and not has_parking:
        _on_interaction_message("Checkpoint rejected: cleanup requires finished parking history")
        return false
    if not has_cleanup and is_instance_valid(cleanup_world):
        _on_interaction_message("Checkpoint predates active cleanup; restart level to restore an earlier campaign stage")
        return false
    if has_parking and not has_live:
        _on_interaction_message("Checkpoint rejected: parking requires completed wrong-way history")
        return false
    if not has_parking and is_instance_valid(parking_world):
        _on_interaction_message("Checkpoint has no parking world; restart the level to load the earlier campaign stage")
        return false
    if not has_live and is_instance_valid(wrong_way_world):
        _on_interaction_message("Checkpoint has no active wrong-way mission; restart the level to load it")
        return false
    var junction: Node = get_node_or_null("FourWayJunction")
    var graph: CivicRoadGraph = null
    var spawner: CivicTrafficSpawner = null
    if junction != null:
        graph = junction.get("road_graph") as CivicRoadGraph
        spawner = junction.get("traffic_spawner") as CivicTrafficSpawner
    if has_live and not CivicWrongWayLiveMission.checkpoint_valid(saved["wrong_way_checkpoint"], graph, civic):
        _on_interaction_message("Checkpoint rejected: wrong-way incident data is inconsistent")
        return false
    if has_parking:
        if not bool(saved["wrong_way_checkpoint"].get("finished", false)):
            _on_interaction_message("Checkpoint rejected: parking started before traffic recovered")
            return false
        var reasons: Array = []
        if not CivicIllegalParkingMission.checkpoint_valid(saved["parking_checkpoint"], civic, reasons):
            _on_interaction_message("Checkpoint rejected: invalid parking mission %s" % str(reasons))
            return false
    if has_cleanup:
        if not bool(saved["parking_checkpoint"].get("finished", false)):
            _on_interaction_message("Checkpoint rejected: market cleanup requires a reopened footpath")
            return false
        var cleanup_failures: Array = []
        if not CivicMarketCleanupMission.checkpoint_valid(saved["cleanup_checkpoint"], civic, cleanup_failures):
            _on_interaction_message("Checkpoint rejected: invalid market cleanup %s" % str(cleanup_failures))
            return false
    if has_finale and not DistrictCampaign.checkpoint_valid(
            saved["campaign_checkpoint"], civic, saved.get("wrong_way_checkpoint"),
            saved.get("parking_checkpoint"), saved.get("cleanup_checkpoint")):
        _on_interaction_message("Checkpoint rejected: forged or inconsistent Free Roam unlock")
        return false
    if has_cleanup and bool(saved["cleanup_checkpoint"].get("finished", false)) and not DistrictCampaign.can_unlock(
            civic, saved["wrong_way_checkpoint"], saved["parking_checkpoint"], saved["cleanup_checkpoint"]):
        _on_interaction_message("Checkpoint rejected: completed cleanup is missing campaign achievements")
        return false
    if has_roam and not CivicFreeRoamEvents.checkpoint_valid(saved["free_roam_checkpoint"], civic):
        _on_interaction_message("Checkpoint rejected: invalid Free Roam events or duplicated civic resolution")
        return false
    var has_world: bool = saved.has("world_checkpoint")
    var pedestrian_world: Node3D = get_node_or_null("DistrictPedestrians") as Node3D
    if has_world and (junction == null or pedestrian_world == null or not bool(junction.call("checkpoint_valid", saved["world_checkpoint"], pedestrian_world))):
        _on_interaction_message("Checkpoint rejected: corrupted or incompatible city simulation")
        return false
    var restored_world: CivicWrongWayLiveMission = wrong_way_world
    var newly_prepared: bool = false
    if has_live and not is_instance_valid(restored_world):
        restored_world = WrongWayLiveMission.new() as CivicWrongWayLiveMission
        restored_world.name = "WrongWayLiveMission"
        add_child(restored_world)
        if not restored_world.prepare_restore(self, player, graph, gameplay_session, spawner):
            restored_world.queue_free()
            _on_interaction_message("Checkpoint deferred: can't safely reconstruct road vehicles")
            return false
        newly_prepared = true
    var restored_parking: CivicIllegalParkingMission = parking_world
    var newly_prepared_parking: bool = false
    if has_parking and not is_instance_valid(restored_parking):
        restored_parking = ParkingMission.new() as CivicIllegalParkingMission
        restored_parking.name = "IllegalParkingMission"
        add_child(restored_parking)
        if not restored_parking.prepare_restore(self, player, gameplay_session):
            restored_parking.queue_free()
            if newly_prepared:
                restored_world.queue_free()
            _on_interaction_message("Checkpoint deferred: parking vehicle space is occupied")
            return false
        newly_prepared_parking = true
    var restored_cleanup: CivicMarketCleanupMission = cleanup_world
    var newly_prepared_cleanup: bool = false
    if has_cleanup and not is_instance_valid(restored_cleanup):
        restored_cleanup = CleanupMission.new() as CivicMarketCleanupMission
        restored_cleanup.name = "MarketCleanupMission"
        add_child(restored_cleanup)
        if not restored_cleanup.prepare_restore(self, player, gameplay_session):
            restored_cleanup.queue_free()
            if newly_prepared_parking:
                restored_parking.queue_free()
            if newly_prepared:
                restored_world.queue_free()
            _on_interaction_message("Checkpoint deferred: cannot stage market cleanup props")
            return false
        newly_prepared_cleanup = true
    # GAME-018: pause the involved civic and physical actors for the entire
    # multi-manager application/rollback; restore their previous processing
    # state on every success or failure path.
    var background_director: Node = null
    if junction != null:
        background_director = junction.get("simulation") as Node
    var restore_guard: CivicCheckpointTransaction = CheckpointTransaction.new()
    if not restore_guard.begin([gameplay_session, restored_world, restored_parking, restored_cleanup, background_director, pedestrian_world]):
        return false
    var old_world_state: Dictionary = {}
    if has_world:
        old_world_state = junction.call("checkpoint_state", pedestrian_world)
    var old_civic: Dictionary = gameplay_session.snapshot()
    var old_live: Dictionary = wrong_way_world.snapshot() if is_instance_valid(wrong_way_world) else {}
    var old_parking: Dictionary = parking_world.snapshot() if is_instance_valid(parking_world) else {}
    var old_cleanup: Dictionary = cleanup_world.snapshot() if is_instance_valid(cleanup_world) else {}
    if not gameplay_session.restore(civic):
        if newly_prepared:
            restored_world.queue_free()
        if newly_prepared_parking:
            restored_parking.queue_free()
        if newly_prepared_cleanup:
            restored_cleanup.queue_free()
        restore_guard.finish()
        _on_interaction_message("Checkpoint rejected: civic restore failed")
        return false
    if has_live and not restored_world.restore(saved["wrong_way_checkpoint"]):
        gameplay_session.restore(old_civic)
        if newly_prepared:
            restored_world.queue_free()
        elif is_instance_valid(wrong_way_world):
            wrong_way_world.restore(old_live)
        if newly_prepared_parking:
            restored_parking.queue_free()
        if newly_prepared_cleanup:
            restored_cleanup.queue_free()
        restore_guard.finish()
        _on_interaction_message("Checkpoint rejected: wrong-way world could not be rebuilt")
        return false
    if has_parking and not restored_parking.restore(saved["parking_checkpoint"]):
        gameplay_session.restore(old_civic)
        if newly_prepared:
            restored_world.queue_free()
        elif is_instance_valid(wrong_way_world):
            wrong_way_world.restore(old_live)
        if newly_prepared_parking:
            restored_parking.queue_free()
        elif is_instance_valid(parking_world):
            parking_world.restore(old_parking)
        if newly_prepared_cleanup:
            restored_cleanup.queue_free()
        restore_guard.finish()
        _on_interaction_message("Checkpoint rejected: parked vehicle or pedestrian could not be reconstructed")
        return false
    if has_cleanup and not restored_cleanup.restore(saved["cleanup_checkpoint"]):
        gameplay_session.restore(old_civic)
        if newly_prepared:
            restored_world.queue_free()
        elif is_instance_valid(wrong_way_world):
            wrong_way_world.restore(old_live)
        if newly_prepared_parking:
            restored_parking.queue_free()
        elif is_instance_valid(parking_world):
            parking_world.restore(old_parking)
        if newly_prepared_cleanup:
            restored_cleanup.queue_free()
        elif is_instance_valid(cleanup_world):
            cleanup_world.restore(old_cleanup)
        restore_guard.finish()
        _on_interaction_message("Checkpoint rejected: litter, bin or worker state could not be restored")
        return false
    # The background world uses the same verified document and is also
    # restored under the director/pedestrian physics guard. Missing world
    # checkpoints are legacy saves: keep the current background simulation.
    if has_world and not bool(junction.call("restore_checkpoint", saved["world_checkpoint"], pedestrian_world)):
        gameplay_session.restore(old_civic)
        if newly_prepared:
            restored_world.queue_free()
        elif is_instance_valid(wrong_way_world):
            wrong_way_world.restore(old_live)
        if newly_prepared_parking:
            restored_parking.queue_free()
        elif is_instance_valid(parking_world):
            parking_world.restore(old_parking)
        if newly_prepared_cleanup:
            restored_cleanup.queue_free()
        elif is_instance_valid(cleanup_world):
            cleanup_world.restore(old_cleanup)
        restore_guard.finish()
        _on_interaction_message("Checkpoint rejected: background vehicles or pedestrians cannot be staged safely")
        return false
    # This method is running on the physics tick. Validate and place the
    # player against the newly restored physical world *before* accepting
    # the checkpoint; failure takes the existing civic/world rollback path.
    if not lifecycle.restore_player_snapshot_now(player, saved):
        gameplay_session.restore(old_civic)
        if newly_prepared:
            restored_world.queue_free()
        elif is_instance_valid(wrong_way_world):
            wrong_way_world.restore(old_live)
        if newly_prepared_parking:
            restored_parking.queue_free()
        elif is_instance_valid(parking_world):
            parking_world.restore(old_parking)
        if newly_prepared_cleanup:
            restored_cleanup.queue_free()
        elif is_instance_valid(cleanup_world):
            cleanup_world.restore(old_cleanup)
        if has_world and not bool(junction.call("restore_checkpoint", old_world_state, pedestrian_world)):
            push_warning("Checkpoint rollback could not restore previous background world")
        restore_guard.finish()
        return false
    if newly_prepared_parking:
        parking_world = restored_parking
        _connect_parking_signals(restored_parking)
    if newly_prepared_cleanup:
        cleanup_world = restored_cleanup
        _connect_cleanup_signals(restored_cleanup)
    if newly_prepared:
        wrong_way_world = restored_world
        _connect_wrong_way_signals(restored_world)
    restore_guard.finish()
    free_roam_unlocked = has_cleanup and is_instance_valid(restored_cleanup) and restored_cleanup.finished and _campaign_ready()
    _finale_acknowledged = bool(saved["campaign_checkpoint"]["finale_acknowledged"]) if has_finale else false
    if district_finale != null:
        district_finale.set_unlocked(free_roam_unlocked)
    if free_roam_unlocked and _finale_acknowledged:
        _start_free_roam_events(saved.get("free_roam_checkpoint", {}))
    if free_roam_unlocked and not _finale_acknowledged:
        call_deferred("_present_campaign_finale")
    if has_parking and not has_cleanup and is_instance_valid(restored_parking) and restored_parking.finished:
        call_deferred("_start_market_cleanup_mission")
    if has_live and not has_parking and is_instance_valid(restored_world) and restored_world.finished:
        call_deferred("_start_illegal_parking_mission")
    if not has_live and gameplay_session.finished:
        call_deferred("_start_wrong_way_mission")
    if civic_hud != null and is_instance_valid(wrong_way_world):
        var state: Dictionary = civic_hud.current_state()
        state.merge(wrong_way_world.hud_state(), true)
        civic_hud.render_state(state)
    _on_interaction_message("Checkpoint restored. All active civic incidents and physical actors resumed.")
    _refresh_mission_guide()
    return true

func _connect_wrong_way_signals(live: CivicWrongWayLiveMission) -> void:
    if not live.incident_card_requested.is_connected(_on_wrong_way_card_requested):
        live.incident_card_requested.connect(_on_wrong_way_card_requested)
    if not live.feedback_changed.is_connected(_on_interaction_message):
        live.feedback_changed.connect(_on_interaction_message)
    if not live.mission_completed.is_connected(_on_wrong_way_mission_completed):
        live.mission_completed.connect(_on_wrong_way_mission_completed)

## Once the first playable tutorial is complete, stage a second physical
## mission on the same west approach of the existing city road graph.
func _on_footpath_tutorial_completed() -> void:
    call_deferred("_start_wrong_way_mission")

func _start_wrong_way_mission() -> void:
    if is_instance_valid(wrong_way_world) or gameplay_session == null:
        return
    var junction: Node = get_node_or_null("FourWayJunction")
    if junction == null:
        push_warning("Wrong-way mission not started: junction missing")
        return
    var graph: CivicRoadGraph = junction.get("road_graph") as CivicRoadGraph
    if graph == null:
        push_warning("Wrong-way mission not started: city lane graph unavailable")
        return
    var live: CivicWrongWayLiveMission = WrongWayLiveMission.new() as CivicWrongWayLiveMission
    live.name = "WrongWayLiveMission"
    add_child(live)
    var traffic_system: CivicTrafficSpawner = junction.get("traffic_spawner") as CivicTrafficSpawner
    if not live.configure(self, player, graph, gameplay_session, traffic_system):
        live.queue_free()
        push_warning("Wrong-way mission could not stage a clear, safe road scenario")
        return
    wrong_way_world = live
    _connect_wrong_way_signals(live)
    _on_interaction_message("NEW MISSION: Wrong Way, Wrong Day. Follow the west road to the yellow report post.")
    _refresh_mission_guide()


## GAME-016 starts only after real GAME-012/013 traffic recovery.
func _on_wrong_way_mission_completed() -> void:
    call_deferred("_start_illegal_parking_mission")

func _start_illegal_parking_mission() -> void:
    if is_instance_valid(parking_world) or gameplay_session == null or not is_instance_valid(wrong_way_world) or not wrong_way_world.finished:
        return
    var live: CivicIllegalParkingMission = ParkingMission.new() as CivicIllegalParkingMission
    live.name = "IllegalParkingMission"
    add_child(live)
    if not live.configure(self, player, gameplay_session):
        live.queue_free()
        push_warning("Illegal parking could not be staged safely")
        return
    parking_world = live
    _connect_parking_signals(live)
    _on_interaction_message("NEW MISSION: Footpath First. Watch the pedestrian and talk to the nearby car owner.")
    _refresh_mission_guide()

func _connect_parking_signals(live: CivicIllegalParkingMission) -> void:
    if not live.mission_completed.is_connected(_on_parking_mission_completed):
        live.mission_completed.connect(_on_parking_mission_completed)
    if not live.incident_card_requested.is_connected(_on_parking_card_requested):
        live.incident_card_requested.connect(_on_parking_card_requested)
    if not live.feedback_changed.is_connected(_on_interaction_message):
        live.feedback_changed.connect(_on_interaction_message)

## GAME-021 begins only after the real pedestrian has crossed the
## previously occupied footpath, not merely when the owner says yes.
func _on_parking_mission_completed() -> void:
    call_deferred("_start_market_cleanup_mission")

func _start_market_cleanup_mission() -> void:
    if is_instance_valid(cleanup_world) or gameplay_session == null or not is_instance_valid(parking_world) or not parking_world.finished:
        return
    var cleanup: CivicMarketCleanupMission = CleanupMission.new() as CivicMarketCleanupMission
    cleanup.name = "MarketCleanupMission"
    add_child(cleanup)
    if not cleanup.configure(self, player, gameplay_session):
        cleanup.queue_free()
        push_warning("Market Clean-Up could not stage its physical items")
        return
    cleanup_world = cleanup
    _connect_cleanup_signals(cleanup)
    _on_interaction_message("NEW MISSION: Market Clean-Up Chain. Inspect wrappers and use the limited-capacity green bin.")
    _refresh_mission_guide()

func _connect_cleanup_signals(cleanup: CivicMarketCleanupMission) -> void:
    if not cleanup.mission_completed.is_connected(_on_cleanup_mission_completed):
        cleanup.mission_completed.connect(_on_cleanup_mission_completed)
    if not cleanup.incident_card_requested.is_connected(_on_cleanup_card_requested):
        cleanup.incident_card_requested.connect(_on_cleanup_card_requested)
    if not cleanup.feedback_changed.is_connected(_on_interaction_message):
        cleanup.feedback_changed.connect(_on_interaction_message)

## GAME-022: Free Roam is earned by four real mission completions.
## Scorecard is derived from manager history; reopening cannot grant points.
func _campaign_ready() -> bool:
    if gameplay_session == null or not is_instance_valid(wrong_way_world) or not is_instance_valid(parking_world) or not is_instance_valid(cleanup_world):
        return false
    return DistrictCampaign.can_unlock(gameplay_session.snapshot(), wrong_way_world.snapshot(),
        parking_world.snapshot(), cleanup_world.snapshot())

func _on_cleanup_mission_completed() -> void:
    if not _campaign_ready():
        push_warning("District finale deferred: mission rewards or incident history incomplete")
        return
    free_roam_unlocked = true
    _finale_acknowledged = false
    if district_finale != null:
        district_finale.set_unlocked(true)
    # Save the earned unlock before opening a paused results screen.
    # A failed write leaves the reward in memory and permits a later F5.
    if not _save_gameplay_checkpoint():
        _on_interaction_message("Free Roam unlocked, but autosave was unavailable. Press F5 after continuing.")
    call_deferred("_present_campaign_finale")

func _present_campaign_finale() -> void:
    if not free_roam_unlocked or not _campaign_ready() or district_finale == null or district_finale.is_open():
        return
    var report: Dictionary = DistrictCampaign.scorecard(gameplay_session.snapshot(),
        wrong_way_world.snapshot(), parking_world.snapshot(), cleanup_world.snapshot())
    if report.is_empty():
        return
    if incident_card != null and incident_card.is_open():
        incident_card.dismiss()
    if not district_finale.present(report):
        return
    lifecycle.set_paused(true)
    pause_panel.visible = false
    if civic_hud != null:
        civic_hud.visible = false
    if mission_guide != null:
        mission_guide.visible = false
    if touch_layer != null:
        touch_layer.visible = false

func _on_finale_continue() -> void:
    if district_finale == null or not district_finale.is_open() or not free_roam_unlocked:
        return
    _finale_acknowledged = true
    district_finale.dismiss()
    lifecycle.set_paused(false)
    pause_panel.visible = false
    if civic_hud != null:
        civic_hud.visible = true
    if mission_guide != null:
        mission_guide.visible = true
    if touch_layer != null:
        touch_layer.visible = true
    _refresh_mission_guide()
    _start_free_roam_events()
    _on_interaction_message("FREE ROAM UNLOCKED | Explore Market Chowk. Civic events will appear periodically.")
    call_deferred("_save_free_roam_acknowledgement")

func _start_free_roam_events(saved_state: Dictionary = {}) -> void:
    if not free_roam_unlocked or not _finale_acknowledged or gameplay_session == null or player == null:
        return
    if not is_instance_valid(free_roam_world):
        var world: CivicFreeRoamEvents = FreeRoamEvents.new() as CivicFreeRoamEvents
        world.name = "FreeRoamEvents"
        add_child(world)
        if not world.configure(player, gameplay_session):
            world.queue_free()
            push_warning("Free Roam events could not start; district exploration remains available")
            return
        free_roam_world = world
        world.incident_card_requested.connect(_on_free_roam_card_requested)
        world.feedback_changed.connect(_on_interaction_message)
        world.incident_resolved.connect(_on_free_roam_event_resolved)
        world.npc_reaction_requested.connect(_on_free_roam_npc_reaction)
    if not saved_state.is_empty() and not free_roam_world.restore_checkpoint(saved_state):
        push_warning("Free Roam event state could not be rehydrated; avoid overwriting the saved checkpoint")

func _on_free_roam_npc_reaction(at: Vector3, kind: String, phase: String, instance_id: int) -> void:
    var walkers: Node = get_node_or_null("DistrictPedestrians")
    if walkers != null and walkers.has_method("react_to_incident"):
        walkers.call("react_to_incident", at, kind, phase, instance_id)

func _on_free_roam_card_requested(state: Dictionary) -> void:
    _show_incident_card(state, free_roam_world)

func _on_free_roam_event_resolved(kind: String) -> void:
    _on_interaction_message("CIVIC ACTION COMPLETE | %s | City scores updated from real cleanup." % kind)
    _refresh_mission_guide()

func _save_free_roam_acknowledgement() -> void:
    if free_roam_unlocked and _finale_acknowledged:
        if not _save_gameplay_checkpoint():
            _on_interaction_message("Free Roam active. Autosave unavailable; try F5 later.")

func _on_finale_replay() -> void:
    if district_finale != null and district_finale.is_open():
        district_finale.dismiss()
    lifecycle.restart_game()

func _on_cleanup_card_requested(state: Dictionary) -> void:
    _show_incident_card(state, cleanup_world)

func _on_parking_card_requested(state: Dictionary) -> void:
    _show_incident_card(state, parking_world)

func _on_incident_card_requested(state: Dictionary) -> void:
    _show_incident_card(state, gameplay_session)

func _on_wrong_way_card_requested(state: Dictionary) -> void:
    _show_incident_card(state, wrong_way_world)

func _show_incident_card(state: Dictionary, source: Node) -> void:
    if get_tree().paused or incident_card == null or incident_card.is_open() or source == null:
        return
    _card_source = source
    incident_card.present(state)
    player.set_physics_process(false)
    player.set_process_unhandled_input(false)
    if touch_layer != null:
        touch_layer.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_incident_card_action(action: String) -> void:
    if incident_card == null or not incident_card.is_open() or not is_instance_valid(_card_source):
        return
    var accepted: bool = bool(_card_source.call("perform_incident_action", player, action))
    var state: Dictionary = _card_source.call("incident_card_state")
    incident_card.render_card(state)
    if accepted and action == "inspect" and not incident_card.report_button.disabled:
        incident_card.report_button.grab_focus()
    elif accepted and ["report", "request_owner", "collect_litter", "deposit_litter", "request_service", "collect_sign", "place_sign"].has(action):
        incident_card.close_button.grab_focus()

func _on_incident_card_dismissed() -> void:
    _card_source = null
    player.set_physics_process(true)
    player.set_process_unhandled_input(true)
    if touch_layer != null:
        touch_layer.visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("mobile") else Input.MOUSE_MODE_CAPTURED

## GAME-015: mission directions are based on physical marker positions.
## No live queue values are guessed or modified by the UI.
func _refresh_mission_guide() -> void:
    if mission_guide == null or gameplay_session == null:
        return
    var state: Dictionary = {}
    if free_roam_unlocked:
        if is_instance_valid(free_roam_world):
            state = free_roam_world.guidance_state()
        else:
            state = {
                "title": "Free Roam | Market Chowk",
                "objective": "Campaign complete. Explore the city or press F2 / District Results.",
                "speaker": "Neighborhood Radio",
                "dialogue": "Public-space civic activities will appear while you explore.",
                "has_target": false, "recovery_available": false
            }
    elif is_instance_valid(cleanup_world):
        state = cleanup_world.guidance_state()
    elif is_instance_valid(parking_world):
        state = parking_world.guidance_state()
    elif is_instance_valid(wrong_way_world):
        state = wrong_way_world.guidance_state()
    elif gameplay_session.finished:
        state = {
            "title": "Wrong Way, Wrong Day",
            "objective": "Traffic is clearing. Municipal staff are preparing the next incident.",
            "speaker": "Neighborhood Radio",
            "dialogue": "Stay on the sidewalk while city vehicles enter.",
            "has_target": false,
            "recovery_available": false
        }
    else:
        state = gameplay_session.guidance_state()
    var forward: Vector3 = -player.global_transform.basis.z
    if player.camera != null:
        forward = -player.camera.global_transform.basis.z
    mission_guide.update_guide(state, player.global_position, forward)

func _on_mission_recovery_action(action: String) -> void:
    if not is_instance_valid(wrong_way_world) or not wrong_way_world.recovery_help_needed():
        return
    match action:
        "reload_checkpoint":
            if incident_card != null and incident_card.is_open():
                incident_card.dismiss()
            if not _queue_gameplay_checkpoint_load():
                _on_interaction_message("Checkpoint load already pending. You can restart the level instead.")
        "restart_level":
            # Confirmation is handled by the guide's ConfirmationDialog.
            lifecycle.restart_game()

func _toggle_pause() -> void:
    if district_finale != null and district_finale.is_open():
        return
    if incident_card != null and incident_card.is_open():
        incident_card.dismiss()
    lifecycle.set_paused(not get_tree().paused)
    pause_panel.visible = get_tree().paused
    if civic_hud != null:
        civic_hud.visible = not get_tree().paused
    if mission_guide != null:
        mission_guide.visible = not get_tree().paused

func _on_resume_pressed() -> void:
    lifecycle.set_paused(false)
    pause_panel.visible = false
    if civic_hud != null:
        civic_hud.visible = true
    if mission_guide != null:
        mission_guide.visible = true

func _on_menu_pressed() -> void:
    lifecycle.return_to_menu()

func _on_interaction_message(message: String) -> void:
    status_label.text = message
    if civic_hud != null:
        var state := civic_hud.current_state()
        state["feedback"] = message
        civic_hud.render_state(state)

func _process(delta: float) -> void:
    if gameplay_session != null and gameplay_session.finished and not is_instance_valid(wrong_way_world):
        _wrong_way_retry_elapsed += delta
        if _wrong_way_retry_elapsed >= 4.0:
            _wrong_way_retry_elapsed = 0.0
            call_deferred("_start_wrong_way_mission")
    if is_instance_valid(wrong_way_world) and wrong_way_world.finished and not is_instance_valid(parking_world):
        _wrong_way_retry_elapsed += delta
        if _wrong_way_retry_elapsed >= 4.0:
            _wrong_way_retry_elapsed = 0.0
            call_deferred("_start_illegal_parking_mission")
    _traffic_display_elapsed += delta
    if _traffic_display_elapsed < 0.5 or civic_hud == null:
        return
    _traffic_display_elapsed = 0.0
    _refresh_mission_guide()
    var junction := get_node_or_null("FourWayJunction")
    if junction == null:
        return
    var spawner: CivicTrafficSpawner = junction.get("traffic_spawner") as CivicTrafficSpawner
    if spawner == null:
        return
    var metrics: Dictionary = spawner.metrics()
    var state: Dictionary = civic_hud.current_state()
    if is_instance_valid(wrong_way_world):
        metrics["wrong_way_queue"] = wrong_way_world.stopped_count
        metrics["wrong_way_peak"] = wrong_way_world.peak_stopped
        state.merge(wrong_way_world.hud_state(), true)
    if is_instance_valid(parking_world):
        var parking_mission: Dictionary = gameplay_session.missions.missions.get(CivicIllegalParkingMission.MISSION_ID, {})
        state["mission"] = parking_mission.duplicate(true)
        state["incidents"] = 0 if parking_world.finished else 1
        state["feedback"] = parking_world.feedback
        state["scores"] = gameplay_session.metrics.scores.duplicate(true)
        state["reputation"] = gameplay_session.metrics.reputation()
    if is_instance_valid(cleanup_world):
        var cleanup_mission: Dictionary = gameplay_session.missions.missions.get(CivicMarketCleanupMission.MISSION_ID, {})
        state["mission"] = cleanup_mission.duplicate(true)
        state["incidents"] = 0 if cleanup_world.finished else 1
        state["feedback"] = cleanup_world.feedback
        state["scores"] = gameplay_session.metrics.scores.duplicate(true)
        state["reputation"] = gameplay_session.metrics.reputation()
    if free_roam_unlocked:
        state["mission"] = {"id": "district_free_roam", "state": "unlocked",
            "progress": {}, "objectives": []}
        if is_instance_valid(free_roam_world):
            var roam_metrics: Dictionary = free_roam_world.hud_state()
            state.merge(roam_metrics, true)
            state["incidents"] = 1 if not free_roam_world.active_event.is_empty() else 0
            state["scores"] = gameplay_session.metrics.scores.duplicate(true)
            state["reputation"] = gameplay_session.metrics.reputation()
            state["feedback"] = free_roam_world.feedback
        else:
            state["incidents"] = 0
            state["feedback"] = "FREE ROAM UNLOCKED  |  F2 District Results"
    state["traffic"] = metrics
    civic_hud.render_state(state)
