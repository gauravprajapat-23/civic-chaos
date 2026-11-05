class_name CivicDebugOverlay
extends CanvasLayer
## Toggleable developer overlay. Feed only observed simulation snapshots.
const Telemetry = preload("res://scripts/debug/debug_telemetry.gd")
var telemetry := Telemetry.new()
var panel: PanelContainer
var output: Label
var enabled: bool = false

func _ready() -> void:
    layer = 20
    panel = PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.position = Vector2(12, 320)
    panel.custom_minimum_size = Vector2(380, 0)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(panel)
    output = Label.new()
    output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    output.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(output)
    set_enabled(false)

func set_enabled(value: bool) -> void:
    enabled = value
    if panel != null:
        panel.visible = value
    if value:
        refresh()

func refresh() -> void:
    if output == null:
        return
    var snapshot := telemetry.latest()
    if snapshot.is_empty():
        output.text = "AI DEBUG | Waiting for telemetry"
        return
    output.text = "AI DEBUG | Tick %d\nTraffic: %s\nRoutes: %s\nReservations: %s\nDecisions: %s\nDeadlocks: %s\nTiming: %s" % [int(snapshot["tick"]), str(snapshot["traffic"]), str(snapshot["routes"]), str(snapshot["reservations"]), str(snapshot["decisions"]), str(snapshot["deadlocks"]), str(snapshot["timing"])]

func record_snapshot(tick: int, traffic: Dictionary, routes: Dictionary, reservations: Dictionary, decisions: Dictionary, deadlocks: Dictionary, timing: Dictionary) -> bool:
    var accepted := telemetry.record(tick, traffic, routes, reservations, decisions, deadlocks, timing)
    if accepted and enabled:
        refresh()
    return accepted

func export_snapshot() -> bool:
    return telemetry.export_json("user://civic_ai_telemetry.json")
