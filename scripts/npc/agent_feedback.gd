class_name CivicAgentFeedback
extends Node3D
## Presentation-only state cues; never change simulation behavior.
signal cue_changed(state: String)
const STATES := ["idle", "moving", "braking", "stopped", "alert", "completed"]
@export var moving_threshold_mps: float = 0.25
@export var braking_threshold_mps: float = 0.75
var state: String = "idle"
var previous_speed: float = 0.0
var cue_label: Label3D
var audio: AudioStreamPlayer3D

func _ready() -> void:
    cue_label = Label3D.new()
    cue_label.name = "CueLabel"
    cue_label.position = Vector3(0, 2.0, 0)
    cue_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    cue_label.font_size = 28
    add_child(cue_label)
    audio = AudioStreamPlayer3D.new()
    audio.name = "CueAudio"
    add_child(audio)
    set_state(state)

func set_state(next_state: String) -> bool:
    if not STATES.has(next_state):
        return false
    if state == next_state and cue_label != null and cue_label.text == _text_for(next_state):
        return true
    state = next_state
    if cue_label != null:
        cue_label.text = _text_for(state)
    cue_changed.emit(state)
    if audio != null and audio.stream != null and ["alert", "braking"].has(state):
        audio.play()
    return true

func observe_vehicle(speed_mps: float, is_active: bool, is_alert: bool = false) -> void:
    if not is_finite(speed_mps) or speed_mps < 0.0:
        return
    var next_state := "moving"
    if not is_active:
        next_state = "completed"
    elif is_alert:
        next_state = "alert"
    elif speed_mps < moving_threshold_mps:
        next_state = "stopped"
    elif previous_speed - speed_mps >= braking_threshold_mps:
        next_state = "braking"
    set_state(next_state)
    previous_speed = speed_mps

func _text_for(value: String) -> String:
    match value:
        "idle": return "Waiting"
        "moving": return "Moving"
        "braking": return "Slowing"
        "stopped": return "Stopped"
        "alert": return "!"
        "completed": return ""
    return ""
