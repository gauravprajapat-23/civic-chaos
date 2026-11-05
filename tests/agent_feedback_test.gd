extends SceneTree

const Feedback = preload("res://scripts/npc/agent_feedback.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var agent := Feedback.new()
    root.add_child(agent)
    await process_frame
    assert(agent.state == "idle")
    assert(not agent.set_state("teleport"))
    agent.observe_vehicle(5.0, true)
    assert(agent.state == "moving")
    agent.observe_vehicle(3.0, true)
    assert(agent.state == "braking")
    agent.observe_vehicle(0.0, true)
    assert(agent.state == "stopped")
    agent.observe_vehicle(0.0, true, true)
    assert(agent.state == "alert")
    agent.observe_vehicle(0.0, false)
    assert(agent.state == "completed")
    assert(agent.cue_label.text.is_empty())
    assert(agent.audio != null)
    agent.queue_free()
    print("CIVIC_CHAOS_AGENT_FEEDBACK_PASS")
    quit(0)
