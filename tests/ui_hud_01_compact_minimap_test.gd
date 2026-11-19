extends SceneTree
## UI-HUD-01: safe minimap, camera-facing projection and compact
## text panels at desktop and Android screen sizes.
const Map = preload("res://scripts/ui/civic_city_map.gd")
const HUD = preload("res://scripts/ui/civic_status_hud.gd")
const Guide = preload("res://scripts/ui/civic_mission_guide.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for viewport in [
        Vector2(320, 568), Vector2(360, 740), Vector2(740, 360),
        Vector2(1280, 720), Vector2(1920, 1080)
    ]:
        var mini: Rect2 = Map.minimap_bounds(viewport)
        var civic: Rect2 = HUD.layout_for(viewport)
        var mission: Rect2 = Guide.panel_bounds(viewport)
        if mini.size.x < 95 or mini.position.x > 18 or mini.end.y + 38 > viewport.y:
            _fail("GTA-style bottom-left map is off-screen " + str(viewport))
            return
        if mini.intersects(civic) or mini.intersects(mission) or civic.intersects(mission):
            _fail("compact HUD layout overlaps active gameplay widgets " + str(viewport))
            return
        if civic.size.y > 80 or mission.size.y > 142:
            _fail("verbose mission or debug wall returned " + str(viewport))
            return
    var area: Rect2 = Rect2(Vector2.ZERO, Vector2(120, 120))
    if Map.minimap_project(Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, area).distance_to(area.get_center()) > 0.01:
        _fail("player is not centered in minimap")
        return
    if Map.minimap_project(Vector3(0,0,-10), Vector3.ZERO, Vector3.FORWARD, area).y >= area.get_center().y:
        _fail("map cannot orient north along player heading")
        return
    if Map.minimap_project(Vector3(-10,0,0), Vector3.ZERO, Vector3.FORWARD, area).x >= area.get_center().x:
        _fail("map cannot place west correctly")
        return
    var stage := Node.new()
    root.add_child(stage)
    var map := Map.new() as CivicCityMap
    stage.add_child(map)
    var hud := HUD.new() as CivicStatusHUD
    stage.add_child(hud)
    var guide := Guide.new() as CivicMissionGuide
    stage.add_child(guide)
    await process_frame
    var actual_mini: Rect2 = Map.minimap_bounds(map.get_viewport().get_visible_rect().size)
    if map.small_frame.position.distance_to(actual_mini.position) > 1.0:
        _fail("minimap geometry ignored live viewport")
        return
    var state: Dictionary = {
        "mission": {"id": "market_illegal_parking", "state": "active",
            "objectives": [{"event": "owner_contacted", "target": 1}],
            "progress": {"owner_contacted": 0}},
        "incidents": 1, "reputation": 525,
        "scores": {"safety": 520, "efficiency": 555, "trust": 500, "cooperation": 525},
        "traffic": {"active": 19, "queue": 9, "completed": 25},
        "feedback": "Inspect the illegal parking evidence."
    }
    hud.render_state(state)
    if hud.current_state() != state or not hud.compact_label.text.contains("REP 525"):
        _fail("compact HUD lost the real civic metrics")
        return
    if hud.mission_label.visible or hud.traffic_label.visible or hud.feedback_label.visible:
        _fail("old raw mission/traffic wall is still visible")
        return
    if hud.compact_label.text.count("\n") > 1:
        _fail("compact civic score contains too many rows")
        return
    guide.update_guide({"title": "Footpath First", "objective": "Talk to the owner and inspect evidence.",
        "dialogue": "A pedestrian has been stopped by the parked car.",
        "has_target": true, "target": Vector3(-16, 0, 0)}, Vector3.ZERO, Vector3.FORWARD)
    if guide.dialogue_label.visible or not guide.mission_label.text.contains("Footpath First") or not guide.waypoint_label.text.contains("WAYPOINT"):
        _fail("compact guide lost current objective or displayed redundant radio text")
        return
    map.update_position(Vector3(2, 0, -3), Vector3.FORWARD,
        {"title": "Footpath First", "has_target": true, "target": Vector3(-16,0,0)})
    if map._navigation_goal().get("target") != Vector3(-16, 0, 0):
        _fail("minimap did not keep the active mission target")
        return
    map.set_expanded(true)
    if not map.large_frame.visible or map.small_frame.visible:
        _fail("full map cannot open after minimap redesign")
        return
    map.set_expanded(false)
    if not map.small_frame.visible or map.large_frame.visible:
        _fail("minimap did not return after full map closed")
        return
    stage.queue_free()
    print("CIVIC_CHAOS_UI_HUD_01_COMPACT_MINIMAP_PASS")
    quit(0)

func _fail(reason: String) -> void:
    push_error(reason)
    quit(1)
