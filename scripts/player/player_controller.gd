class_name CivicPlayerController
extends CharacterBody3D
## Third-person walking controller with collision-aware orbit camera and ray interaction.

signal interaction_attempted(target: Node)
signal interaction_message(message: String)

@export var walk_speed: float = 5.0
@export var sprint_multiplier: float = 1.65
@export var acceleration: float = 16.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.0025
@export var gamepad_look_speed: float = 2.5
@export var interaction_distance: float = 3.0

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var _pitch: float = -0.2
var _gravity: float = 9.8

func _ready() -> void:
    _gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
    _apply_camera_pitch()
    camera.current = true
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)
    elif event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event.is_action_pressed("interact"):
        try_interact()
        get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
    var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
    if look.length_squared() > 0.001:
        rotate_camera(-look.x * gamepad_look_speed * delta, -look.y * gamepad_look_speed * delta)
    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var forward := -camera.global_transform.basis.z
    var right := camera.global_transform.basis.x
    forward.y = 0.0
    right.y = 0.0
    var direction := (right.normalized() * input_vector.x + forward.normalized() * -input_vector.y).normalized()
    var target_speed := walk_speed * (sprint_multiplier if Input.is_action_pressed("sprint") else 1.0)
    var target_velocity := direction * target_speed
    velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
    if is_on_floor():
        if Input.is_action_just_pressed("jump"):
            velocity.y = jump_velocity
        else:
            velocity.y = -0.1
    else:
        velocity.y -= _gravity * delta
    move_and_slide()
    if direction.length_squared() > 0.01:
        visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 12.0 * delta))

func rotate_camera(yaw_delta: float, pitch_delta: float) -> void:
    camera_pivot.rotation.y += yaw_delta
    _pitch = clampf(_pitch + pitch_delta, -1.15, 0.65)
    _apply_camera_pitch()

func _apply_camera_pitch() -> void:
    spring_arm.rotation.x = _pitch

func try_interact() -> void:
    var center := camera.get_viewport().get_visible_rect().size * 0.5
    var origin := camera.project_ray_origin(center)
    var destination := origin + camera.project_ray_normal(center) * interaction_distance
    var query := PhysicsRayQueryParameters3D.create(origin, destination)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        interaction_message.emit("Nothing to interact with")
        return
    var target: Object = hit["collider"]
    if target is Node:
        var node := target as Node
        if node.has_method("interact"):
            node.call("interact", self)
            interaction_attempted.emit(node)
            return
    interaction_message.emit("No interaction available")
