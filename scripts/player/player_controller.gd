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
@export var fall_recovery_height: float = -8.0

var _safe_spawn: Vector3 = Vector3.ZERO

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var _pitch: float = -0.2
var _gravity: float = 9.8
var _look_touch_index: int = -1
var _last_touch_position := Vector2.ZERO
var _walk_animation_time: float = 0.0

func _ready() -> void:
    _safe_spawn = global_position
    _gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
    _apply_camera_pitch()
    camera.current = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("mobile") else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _look_touch_index == -1 and touch.position.x > get_viewport().get_visible_rect().size.x * 0.45:
            _look_touch_index = touch.index
            _last_touch_position = touch.position
        elif not touch.pressed and touch.index == _look_touch_index:
            _look_touch_index = -1
        return
    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _look_touch_index:
            var motion := drag.position - _last_touch_position
            _last_touch_position = drag.position
            rotate_camera(-motion.x * mouse_sensitivity, -motion.y * mouse_sensitivity)
        return
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
    if global_position.y < fall_recovery_height:
        global_position = _safe_spawn
        velocity = Vector3.ZERO
        interaction_message.emit("Returned to safe ground")
        return
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
    # Actor roofs must not act as ground. Sweep horizontal player movement
    # against cars and pedestrians before world-only move_and_slide().
    _limit_horizontal_actor_motion(delta)
    move_and_slide()
    _animate_walk(delta)
    if direction.length_squared() > 0.01:
        visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 12.0 * delta))

## Horizontal contact with pedestrians and vehicles without using either as a floor.
## Static/kinematic traffic still senses player layer 2 for emergency stopping.
func _limit_horizontal_actor_motion(delta: float) -> void:
    var horizontal_motion := Vector3(velocity.x * delta, 0.0, velocity.z * delta)
    if horizontal_motion.length_squared() <= 0.0000001:
        return
    var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collider == null or collider.shape == null:
        return
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = collider.shape
    query.transform = collider.global_transform
    query.motion = horizontal_motion
    query.collision_mask = 4 | 8 # Vehicle and pedestrian bodies; never treated as floors.
    query.exclude = [get_rid()]
    query.margin = 0.02
    var space := get_world_3d().direct_space_state
    # cast_motion intentionally ignores bodies we already overlap. On a bad
    # spawn, allow a player to walk out but not deeper into a pedestrian.
    for overlap in space.intersect_shape(query, 8):
        var obstacle := overlap.get("collider") as Node3D
        if obstacle == null:
            continue
        var away := global_position - obstacle.global_position
        away.y = 0.0
        if away.length_squared() > 0.0001 and horizontal_motion.dot(away) <= 0.0:
            velocity.x = 0.0
            velocity.z = 0.0
            return
    var fractions: PackedFloat32Array = space.cast_motion(query)
    if fractions.size() < 1:
        return
    var safe_fraction: float = clampf(fractions[0], 0.0, 1.0)
    if safe_fraction < 1.0:
        var allowance: float = maxf(0.0, safe_fraction - 0.01)
        velocity.x *= allowance
        velocity.z *= allowance

func rotate_camera(yaw_delta: float, pitch_delta: float) -> void:
    camera_pivot.rotation.y += yaw_delta
    _pitch = clampf(_pitch + pitch_delta, -1.15, 0.65)
    _apply_camera_pitch()

func _apply_camera_pitch() -> void:
    spring_arm.rotation.x = _pitch

func try_interact() -> void:
    var center := camera.get_viewport().get_visible_rect().size * 0.5
    var origin := camera.project_ray_origin(center)
    var destination := origin + camera.project_ray_normal(center) * (spring_arm.spring_length + interaction_distance + 1.0)
    var query := PhysicsRayQueryParameters3D.create(origin, destination)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        interaction_message.emit("Nothing to interact with")
        return
    var target: Object = hit["collider"]
    if target is Node3D:
        var node := target as Node3D
        if global_position.distance_to(node.global_position) > interaction_distance:
            interaction_message.emit("Move closer to interact")
            return
        if node.has_method("interact"):
            node.call("interact", self)
            interaction_attempted.emit(node)
            return
    interaction_message.emit("No interaction available")

func _animate_walk(delta: float) -> void:
    var movement: float = Vector2(velocity.x, velocity.z).length()
    _walk_animation_time += delta * movement * 2.0
    var swing: float = sin(_walk_animation_time) * minf(movement / maxf(walk_speed, 0.1), 1.5) * 0.55
    var left_arm := visual.get_node_or_null("LeftArm") as Node3D
    var right_arm := visual.get_node_or_null("RightArm") as Node3D
    var left_leg := visual.get_node_or_null("LeftLeg") as Node3D
    var right_leg := visual.get_node_or_null("RightLeg") as Node3D
    if left_arm == null or right_arm == null or left_leg == null or right_leg == null:
        return
    left_arm.rotation.x = lerpf(left_arm.rotation.x, swing, minf(1.0, delta * 12.0))
    right_arm.rotation.x = lerpf(right_arm.rotation.x, -swing, minf(1.0, delta * 12.0))
    left_leg.rotation.x = lerpf(left_leg.rotation.x, -swing, minf(1.0, delta * 12.0))
    right_leg.rotation.x = lerpf(right_leg.rotation.x, swing, minf(1.0, delta * 12.0))
