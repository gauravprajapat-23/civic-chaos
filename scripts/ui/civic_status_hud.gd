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
    offset_left = 12.0
    offset_top = 120.0
    offset_right = 360.0
    offset_bottom = 320.0
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
        roam_label.text = "FREE ROAM | Completed %d  Missed %d%s" % [
            int(state.get("free_roam_resolved", 0)),
            int(state.get("free_roam_expired", 0)),
            "  ACTIVE" if not event_name.is_empty() else ""
        ]
    feedback_label.text = str(state.get("feedback", "E interact | F1 pause"))

func current_state() -> Dictionary:
    return _last_state.duplicate(true)
