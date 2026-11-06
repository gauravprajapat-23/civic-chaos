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
const IncidentCard = preload("res://scripts/ui/civic_incident_card.gd")
const SaveRepo = preload("res://scripts/core/save_repository.gd")
var graphics_lod: CivicGraphicsLOD
var debug_overlay: CivicDebugOverlay
var civic_hud: CivicStatusHUD
var gameplay_session: CivicGameplaySession
var wrong_way_world: CivicWrongWayLiveMission
var _card_source: Node
var incident_card: CivicIncidentDetailCard
var touch_layer: CanvasLayer
var _traffic_display_elapsed: float = 0.0
var _wrong_way_retry_elapsed: float = 0.0

func _enter_tree() -> void:
    _bind_key("move_forward", KEY_W)
    _bind_key("move_back", KEY_S)
    _bind_key("move_left", KEY_A)
    _bind_key("move_right", KEY_D)
    _bind_key("sprint", KEY_SHIFT)
    _bind_key("jump", KEY_SPACE)
    _bind_key("interact", KEY_E)
    _bind_key("pause_game", KEY_F1)
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
    print("CIVIC_CHAOS_MAIN_READY")

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo:
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
        _load_gameplay_checkpoint()
    elif event.is_action_pressed("restart_game"):
        lifecycle.restart_game()
    elif event.is_action_pressed("return_to_menu"):
        lifecycle.return_to_menu()

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
    return lifecycle.save_player(player, "", payload)

func _load_gameplay_checkpoint() -> bool:
    var saved: Dictionary = SaveRepo.read_save()
    if saved.is_empty():
        _on_interaction_message("No valid checkpoint found")
        return false
    if not saved.has("civic_session"):
        if is_instance_valid(wrong_way_world):
            _on_interaction_message("Old player-only save cannot replace an active civic incident")
            return false
        return lifecycle.load_player(player)
    var civic: Variant = saved["civic_session"]
    if gameplay_session == null or not gameplay_session.can_restore(civic):
        _on_interaction_message("Checkpoint rejected: invalid civic session")
        return false
    var has_live: bool = saved.has("wrong_way_checkpoint")
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
    # Restore all world actors first. Only request the player's safe-position
    # move after mission reconstruction succeeds, so a rejected checkpoint
    # does not leave a queued player teleport behind.
    var old_civic: Dictionary = gameplay_session.snapshot()
    var old_live: Dictionary = wrong_way_world.snapshot() if is_instance_valid(wrong_way_world) else {}
    if not gameplay_session.restore(civic):
        if newly_prepared:
            restored_world.queue_free()
        _on_interaction_message("Checkpoint rejected: civic restore failed")
        return false
    if has_live and not restored_world.restore(saved["wrong_way_checkpoint"]):
        gameplay_session.restore(old_civic)
        if newly_prepared:
            restored_world.queue_free()
        elif is_instance_valid(wrong_way_world):
            wrong_way_world.restore(old_live)
        _on_interaction_message("Checkpoint rejected: wrong-way world could not be rebuilt")
        return false
    # The player controller performs collision/floor checks and applies
    # accepted positions on the next physics frame.
    if not lifecycle.load_player(player):
        gameplay_session.restore(old_civic)
        if newly_prepared:
            restored_world.queue_free()
        elif is_instance_valid(wrong_way_world):
            wrong_way_world.restore(old_live)
        return false
    if newly_prepared:
        wrong_way_world = restored_world
        _connect_wrong_way_signals(restored_world)
    if not has_live and gameplay_session.finished:
        call_deferred("_start_wrong_way_mission")
    if civic_hud != null and is_instance_valid(wrong_way_world):
        var state: Dictionary = civic_hud.current_state()
        state.merge(wrong_way_world.hud_state(), true)
        civic_hud.render_state(state)
    _on_interaction_message("Checkpoint restored. Mission, vehicles and civic progress resumed.")
    return true

func _connect_wrong_way_signals(live: CivicWrongWayLiveMission) -> void:
    if not live.incident_card_requested.is_connected(_on_wrong_way_card_requested):
        live.incident_card_requested.connect(_on_wrong_way_card_requested)
    if not live.feedback_changed.is_connected(_on_interaction_message):
        live.feedback_changed.connect(_on_interaction_message)

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
    elif accepted and action == "report":
        incident_card.close_button.grab_focus()

func _on_incident_card_dismissed() -> void:
    _card_source = null
    player.set_physics_process(true)
    player.set_process_unhandled_input(true)
    if touch_layer != null:
        touch_layer.visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("mobile") else Input.MOUSE_MODE_CAPTURED

func _toggle_pause() -> void:
    if incident_card != null and incident_card.is_open():
        incident_card.dismiss()
    lifecycle.set_paused(not get_tree().paused)
    pause_panel.visible = get_tree().paused
    if civic_hud != null:
        civic_hud.visible = not get_tree().paused

func _on_resume_pressed() -> void:
    lifecycle.set_paused(false)
    pause_panel.visible = false

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
    _traffic_display_elapsed += delta
    if _traffic_display_elapsed < 0.5 or civic_hud == null:
        return
    _traffic_display_elapsed = 0.0
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
    state["traffic"] = metrics
    civic_hud.render_state(state)
