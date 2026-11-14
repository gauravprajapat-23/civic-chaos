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

const CharacterArt = preload("res://scripts/rendering/low_poly_character.gd")
const INTERACTION_COLLISION_MASK: int = 1 | 16 # Static world targets + nonblocking civic report posts.

var _safe_spawn: Vector3 = Vector3.ZERO
var _restore_pending: bool = false
var _restore_position: Vector3 = Vector3.ZERO
var _restore_yaw: float = 0.0

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var _pitch: float = -0.2
var _gravity: float = 9.8
var _look_touch_index: int = -1
var _last_touch_position := Vector2.ZERO
var _walk_animation_time: float = 0.0
## CAR-ART-04E: a non-climbable car blocks horizontal travel even when
## the player jumps above its short physical collider. Query-only, never a floor.
var _airborne_vehicle_guard: BoxShape3D
const VEHICLE_GUARD_HEIGHT_M: float = 2.7
const VEHICLE_GUARD_WIDTH_M: float = 0.70

func _ready() -> void:
    CharacterArt.build(visual, Color(0.15, 0.39, 0.74), Color(0.72, 0.48, 0.33),
        Color(0.19, 0.24, 0.35), Color(0.92, 0.72, 0.23), -0.9)
    _safe_spawn = global_position
    _gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
    _apply_camera_pitch()
    camera.current = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("mobile") else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _look_touch_index == -1 and touch.position.x > get_viewport().get_visible_rect().size.x * 0.45 and _touch_can_look(touch.position):
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

## Ignore camera-look presses that begin over mobile action buttons.
## Swipes beginning in the free right-hand view area remain independent
## of the left joystick finger.
## Modal/focus changes may interrupt the touch-up event. Clear look
## ownership without changing camera orientation or keyboard input.
func cancel_mobile_look() -> void:
    _look_touch_index = -1
    _last_touch_position = Vector2.ZERO

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        cancel_mobile_look()

func _touch_can_look(point: Vector2) -> bool:
    for node in get_tree().get_nodes_in_group("civic_touch_controls"):
        if node.has_method("look_touch_allowed") and not bool(node.call("look_touch_allowed", point)):
            return false
    return true

func _physics_process(delta: float) -> void:
    # Physics-space queries execute on the physics tick, not from input events.
    if _restore_pending:
        _restore_pending = false
        if _try_place_on_ground(_restore_position):
            rotation.y = _restore_yaw
            interaction_message.emit("Save loaded")
        elif _recover_near_spawn():
            interaction_message.emit("Saved position unsafe; returned to safe spawn")
        else:
            interaction_message.emit("Saved position unsafe; current position retained")
        return
    if global_position.y < fall_recovery_height:
        if _recover_near_spawn():
            interaction_message.emit("Returned to safe ground")
        else:
            velocity = Vector3.ZERO
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
    # Keep car collision horizontal; pedestrians yield without hard blocking.
    # The player stays grounded on world surfaces, not other characters.
    _limit_horizontal_actor_motion(delta)
    move_and_slide()
    # A falling player can still enter an unmoving car from above because
    # vehicle roofs are intentionally not CharacterBody3D floors. Recover
    # to the nearest tested perimeter point before the next physics tick.
    _recover_vehicle_descent_overlap()
    _animate_walk(delta)
    if direction.length_squared() > 0.01:
        visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 12.0 * delta))

## Queue save restoration for the next physics tick so the space is unlocked.
## A queued restore is not considered successful until placement passes checks.
func request_safe_restore(requested: Vector3, yaw: float) -> bool:
    if not requested.is_finite() or not is_finite(yaw) or not is_inside_tree():
        return false
    _restore_position = requested
    _restore_yaw = yaw
    _restore_pending = true
    return true

## Called only from the game's checkpoint transaction on a physics tick.
## Unlike request_safe_restore(), success means the saved position was actually
## placed and checked against the *restored* traffic and pedestrian colliders.
## On failure do not teleport to the fallback spawn: the caller must roll
## back the civic/world transaction and leave the player in place.
func restore_now_safe(requested: Vector3, yaw: float) -> bool:
    _restore_pending = false
    if not requested.is_finite() or not is_finite(yaw) or not is_inside_tree():
        return false
    if not _try_place_on_ground(requested):
        return false
    rotation.y = yaw
    interaction_message.emit("Save loaded")
    return true

## Recovery uses only nearby, grounded and unoccupied points, never arbitrary
## teleportation across the city. Current location is retained if all fail.
func _recover_near_spawn() -> bool:
    var offsets: Array[Vector3] = [
        Vector3.ZERO,
        Vector3(3.0, 0.0, 0.0), Vector3(-3.0, 0.0, 0.0),
        Vector3(0.0, 0.0, 3.0), Vector3(0.0, 0.0, -3.0),
        Vector3(6.0, 0.0, 0.0), Vector3(-6.0, 0.0, 0.0)
    ]
    for offset in offsets:
        if _try_place_on_ground(_safe_spawn + offset):
            return true
    return false

## Only accept nearby world-supported positions that are free of actor and
## environment overlap. Calls must originate in _physics_process().
func _try_place_on_ground(requested: Vector3) -> bool:
    if not is_inside_tree() or not requested.is_finite():
        return false
    var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collider == null or collider.shape == null:
        return false
    var space := get_world_3d().direct_space_state
    var floor_ray := PhysicsRayQueryParameters3D.create(
        requested + Vector3.UP * 0.75,
        requested + Vector3.DOWN * 3.5
    )
    floor_ray.collision_mask = 1 # Floor must be world, never a car or NPC.
    floor_ray.exclude = [get_rid()]
    var floor_hit: Dictionary = space.intersect_ray(floor_ray)
    if floor_hit.is_empty():
        return false
    var normal: Vector3 = floor_hit["normal"]
    if normal.y < 0.7:
        return false
    var floor_point: Vector3 = floor_hit["position"]
    # Leave 12 cm above the surface to avoid overlapping coplanar road slabs.
    var placement := Vector3(requested.x, floor_point.y + 0.12, requested.z)
    if absf(placement.y - requested.y) > 1.25:
        return false
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = collider.shape
    query.transform = Transform3D(
        collider.global_transform.basis, placement + collider.position
    )
    query.collision_mask = 1 | 4 | 8
    query.exclude = [get_rid()]
    query.margin = 0.015
    if not space.intersect_shape(query, 8).is_empty():
        return false
    global_position = placement
    velocity = Vector3.ZERO
    reset_physics_interpolation()
    return true

## Player/body collision stays world-only. Do NOT make cars floors.
## Sweep horizontal intent at both current and predicted vertical heights:
## falling/jumping should not sneak sideways through the cabin.
func _limit_horizontal_actor_motion(delta: float) -> void:
    var horizontal_motion := Vector3(velocity.x * delta, 0.0, velocity.z * delta)
    if horizontal_motion.length_squared() <= 0.0000001:
        return
    var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collider == null or collider.shape == null:
        return
    var space := get_world_3d().direct_space_state
    var safe_fraction: float = 1.0
    for y_offset in [0.0, velocity.y * delta]:
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = collider.shape
        query.transform = Transform3D(collider.global_transform.basis,
            collider.global_position + Vector3.UP * y_offset)
        query.motion = horizontal_motion
        query.collision_mask = 4
        query.exclude = [get_rid()]
        query.margin = 0.02
        # Already overlapping? Never drive *deeper* into that body;
        # normal walk-out remains possible in the opposite direction.
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
        if fractions.size() >= 1:
            safe_fraction = minf(safe_fraction, clampf(fractions[0], 0.0, 1.0))
    # The real vehicle box is only 1.2 m tall: ordinary capsule sweeps
    # no longer detect the car at a jump's apex. Add a *horizontal-only*
    # extended player footprint that reaches the vehicle below the jumper.
    # It never affects floor detection, gravity, signals or NPC clearance.
    if _airborne_vehicle_guard == null:
        _airborne_vehicle_guard = BoxShape3D.new()
        _airborne_vehicle_guard.size = Vector3(
            VEHICLE_GUARD_WIDTH_M, VEHICLE_GUARD_HEIGHT_M,
            VEHICLE_GUARD_WIDTH_M)
    var overhead := PhysicsShapeQueryParameters3D.new()
    overhead.shape = _airborne_vehicle_guard
    overhead.transform = Transform3D(collider.global_transform.basis,
        global_position + Vector3.UP * 0.45)
    overhead.motion = horizontal_motion
    overhead.collision_mask = 4
    overhead.exclude = [get_rid()]
    overhead.margin = 0.015
    for overlap in space.intersect_shape(overhead, 8):
        var obstacle := overlap.get("collider") as Node3D
        if obstacle == null:
            continue
        var away: Vector3 = global_position - obstacle.global_position
        away.y = 0.0
        # If already intersecting the footprint, only outward motion is
        # allowed. Never trap a character attempting to leave a stalled car.
        if away.length_squared() > 0.0001 and horizontal_motion.dot(away) <= 0.0:
            velocity.x = 0.0
            velocity.z = 0.0
            return
    var overhead_fractions: PackedFloat32Array = space.cast_motion(overhead)
    if overhead_fractions.size() >= 1:
        safe_fraction = minf(safe_fraction,
            clampf(overhead_fractions[0], 0.0, 1.0))
    if safe_fraction < 1.0:
        var allowance: float = maxf(0.0, safe_fraction - 0.01)
        velocity.x *= allowance
        velocity.z *= allowance

## Preserve the existing no-car-roof-floor rule. When an airborne character
## descends into a vehicle from above, move to a genuinely free adjacent
## position rather than allowing the visual player to sit inside the cabin.
## This is a last-resort geometry recovery, not an always-on auto-teleport.
func _recover_vehicle_descent_overlap() -> void:
    if not is_inside_tree() or velocity.y >= 0.0:
        return
    var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collider == null or collider.shape == null:
        return
    var space := get_world_3d().direct_space_state
    var probe := PhysicsShapeQueryParameters3D.new()
    probe.shape = collider.shape
    probe.transform = collider.global_transform
    probe.collision_mask = 4
    probe.exclude = [get_rid()]
    probe.margin = 0.015
    for hit in space.intersect_shape(probe, 8):
        var vehicle_body := hit.get("collider") as StaticBody3D
        if vehicle_body == null or (vehicle_body.collision_layer & 4) == 0:
            continue
        var car_shape := vehicle_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
        if car_shape == null or not (car_shape.shape is BoxShape3D):
            continue
        var car_box := car_shape.shape as BoxShape3D
        var local: Vector3 = vehicle_body.to_local(global_position)
        var side: float = signf(local.x) if absf(local.x) > 0.01 else 1.0
        var front: float = signf(local.z) if absf(local.z) > 0.01 else 1.0
        var radius: float = 0.45
        var x_boundary: float = car_box.size.x * 0.5 + radius
        var z_boundary: float = car_box.size.z * 0.5 + radius
        var candidates: Array[Vector3] = [
            vehicle_body.to_global(Vector3(side * x_boundary, local.y, local.z)),
            vehicle_body.to_global(Vector3(local.x, local.y, front * z_boundary))
        ]
        # Minimum displacement wins, but every candidate must be free.
        if global_position.distance_squared_to(candidates[1]) < global_position.distance_squared_to(candidates[0]):
            candidates.reverse()
        for candidate in candidates:
            var placement := Transform3D(collider.global_transform.basis,
                candidate + collider.position)
            var check := PhysicsShapeQueryParameters3D.new()
            check.shape = collider.shape
            check.transform = placement
            check.collision_mask = 1 | 4 | 8
            check.exclude = [get_rid()]
            check.margin = 0.015
            if space.intersect_shape(check, 8).is_empty():
                global_position = candidate
                velocity.x = 0.0
                velocity.z = 0.0
                reset_physics_interpolation()
                return
        # If no safe landing is available, retain the position rather than
        # moving the player through a different car, pedestrian or wall.
        return

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
    query.collision_mask = INTERACTION_COLLISION_MASK
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty() or not (hit.get("collider") is Node3D and
            (hit["collider"] as Node3D).has_method("interact")):
        # Ground-level wrappers are easy to miss with a camera-center ray.
        # Restrict proximity assistance to real cleanup targets near the
        # player's FRONT and require an unobstructed line through solid world.
        var cleanup: Node3D = _nearby_cleanup_target()
        if cleanup != null:
            cleanup.call("interact", self)
            interaction_attempted.emit(cleanup)
            return
        interaction_message.emit("Nothing to interact with" if hit.is_empty() else "No interaction available")
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

## Optional aim assistance applies ONLY to cleanup mission objects. It
## never reaches through walls or changes the general E ray interaction.
func _nearby_cleanup_target() -> Node3D:
    var forward: Vector3 = -camera.global_transform.basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.001:
        return null
    forward = forward.normalized()
    var closest: Node3D = null
    var best_distance: float = INF
    for node in get_tree().get_nodes_in_group("civic_cleanup_targets"):
        var candidate := node as Node3D
        if candidate == null or not candidate.visible or not candidate.has_method("interact"):
            continue
        if candidate is CollisionObject3D and (candidate as CollisionObject3D).collision_layer != 16:
            continue
        var delta: Vector3 = candidate.global_position - global_position
        var planar := Vector3(delta.x, 0.0, delta.z)
        var distance: float = delta.length()
        if distance > interaction_distance or distance < 0.001:
            continue
        if planar.length_squared() > 0.25 and forward.dot(planar.normalized()) < 0.15:
            continue
        var sight := PhysicsRayQueryParameters3D.create(
            global_position + Vector3.UP * 1.3,
            candidate.global_position + Vector3.UP * 0.65)
        sight.collision_mask = 1 | 4
        sight.exclude = [get_rid()]
        if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
            continue
        if distance < best_distance:
            best_distance = distance
            closest = candidate
    return closest

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
