class_name CivicStatusHUD
extends MarginContainer
## Read-only HUD: display only supplied live state, never fabricated telemetry.

var mission_label: Label
var incidents_label: Label
var reputation_label: Label
var dimensions_label: Label
var traffic_label: Label
var roam_label: Label
var feedback_label: Label
var _last_state: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_TOP_LEFT)
    # Prevent the HUD from extending off-screen on narrow portrait devices.
    # This changes presentation only, never the civic metrics data source.
    get_viewport().size_changed.connect(_fit)
    _fit()
    var panel := PanelContainer.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(panel)
    var content := VBoxContainer.new()
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(content)
    mission_label = _line(content)
    incidents_label = _line(content)
    reputation_label = _line(content)
    dimensions_label = _line(content)
    traffic_label = _line(content)
    roam_label = _line(content)
    feedback_label = _line(content)
    render_state({})

## UX-02: pure geometry helper makes small-display behavior testable.
static func layout_for(viewport: Vector2) -> Rect2:
    if not viewport.is_finite() or viewport.x <= 0.0 or viewport.y <= 0.0:
        return Rect2()
    var left: float = 8.0 if viewport.x < 600.0 else 12.0
    var top: float = 80.0 if viewport.y < 560.0 else 120.0
    var available_width: float = maxf(0.0, viewport.x - left * 2.0)
    var width: float = minf(348.0, available_width)
    var height: float = minf(260.0, maxf(0.0, viewport.y - top - 8.0))
    return Rect2(Vector2(left, top), Vector2(width, height))

func _fit() -> void:
    var bounds: Rect2 = layout_for(get_viewport().get_visible_rect().size)
    if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
        return
    offset_left = bounds.position.x
    offset_top = bounds.position.y
    offset_right = bounds.end.x
    offset_bottom = bounds.end.y

func _line(parent: VBoxContainer) -> Label:
    var label := Label.new()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func render_state(state: Dictionary) -> void:
    _last_state = state.duplicate(true)
    if mission_label == null:
        return
    var mission: Dictionary = state.get("mission", {})
    if mission.is_empty():
        mission_label.text = "MISSION | No active mission"
    else:
        var progress: Dictionary = mission.get("progress", {})
        var objectives: Array = mission.get("objectives", [])
        var goals: Array[String] = []
        for objective in objectives:
            if objective is Dictionary:
                var event_name: String = str(objective.get("event", "objective"))
                goals.append("%s %d/%d" % [event_name, int(progress.get(event_name, 0)), int(objective.get("target", 0))])
        mission_label.text = "MISSION | %s (%s)\n%s" % [str(mission.get("id", "Unknown")), str(mission.get("state", "unknown")), ", ".join(goals)]
    var incident_count: Variant = state.get("incidents", null)
    incidents_label.text = "INCIDENTS | --" if incident_count == null else "INCIDENTS | %d" % maxi(0, int(incident_count))
    var reputation: Variant = state.get("reputation", null)
    reputation_label.text = "REPUTATION | --" if reputation == null else "REPUTATION | %d/1000" % clampi(int(reputation), 0, 1000)
    var civic_scores: Dictionary = state.get("scores", {})
    if civic_scores.has("safety") and civic_scores.has("efficiency") and civic_scores.has("trust") and civic_scores.has("cooperation"):
        dimensions_label.text = "CITY | Safety %d  Flow %d\nTrust %d  Cooperation %d" % [
            int(civic_scores["safety"]), int(civic_scores["efficiency"]),
            int(civic_scores["trust"]), int(civic_scores["cooperation"])
        ]
    else:
        dimensions_label.text = "CITY | No civic metrics yet"
    var traffic: Dictionary = state.get("traffic", {})
    traffic_label.text = "TRAFFIC | No live data" if traffic.is_empty() else "TRAFFIC | Active %d  Queued %d  Completed %d" % [maxi(0, int(traffic.get("active", 0))), maxi(0, int(traffic.get("queue", 0))), maxi(0, int(traffic.get("completed", 0)))]
    if traffic.has("wrong_way_queue"):
        traffic_label.text += "\nWRONG WAY | Stopped %d  Peak %d" % [
            maxi(0, int(traffic["wrong_way_queue"])),
            maxi(0, int(traffic.get("wrong_way_peak", 0)))
        ]
    var event_name: String = str(state.get("free_roam_event", ""))
    roam_label.visible = state.has("free_roam_resolved")
    if roam_label.visible:
        roam_label.text = "FREE ROAM | Completed %d  Missed %d" % [
            int(state.get("free_roam_resolved", 0)),
            int(state.get("free_roam_expired", 0))
        ]
        if not event_name.is_empty():
            var category: String = event_name.replace("_", " ").capitalize()
            var location_id: String = str(state.get("free_roam_location", ""))
            roam_label.text += "\nACTIVE | %s%s" % [
                category, " | PRIORITY" if bool(state.get("free_roam_priority", false)) else ""]
            if not location_id.is_empty():
                roam_label.text += "\nDISTRICT | %s" % location_id.replace("_", " ").capitalize()
        var volunteer: Dictionary = state.get("volunteer_progress", {})
        if not volunteer.is_empty():
            roam_label.text += "\nVOLUNTEER | %s" % str(volunteer.get("rank", ""))
            var goal: int = int(volunteer.get("next_goal", 0))
            if goal > 0:
                roam_label.text += "\nNEXT BADGE | %s (%d/%d)" % [
                    str(volunteer.get("next_title", "")),
                    int(volunteer.get("activities", 0)), goal]
            else:
                roam_label.text += "\nBADGES | All milestones reached"
            var rotation: Dictionary = volunteer.get("rotating_goal", {})
            if not rotation.is_empty():
                roam_label.text += "\nCIVIC GOAL | %s (%d/%d)" % [
                    str(rotation.get("title", "")),
                    int(rotation.get("completed", 0)),
                    int(rotation.get("target", 4))]
    feedback_label.text = str(state.get("feedback", "E interact | F1 pause"))

func current_state() -> Dictionary:
    return _last_state.duplicate(true)
