extends Node3D
## Deterministic sidewalk pedestrians with physics clearance and junction reservations.

@export var pedestrian_count: int = 8
@export var district_extent: float = 38.0
var _walkers: Array[Dictionary] = []
var _elapsed: float = 0.0
var _signal_controller: CivicTrafficSignalController
var _traffic_spawner: CivicTrafficSpawner
var _walker_progress: Array[float] = []
var _reservations: CivicIntersectionReservations
var _crossing: Array[bool] = []
const BODY_RADIUS: float = 0.32
const PLAYER_CLEARANCE: float = 1.4
const PLAYER_YIELD_RADIUS: float = 2.3
const PLAYER_YIELD_SPEED: float = 5.5
const WALKER_CLEARANCE: float = 1.05
const CROSSING_CLEARANCE: float = 1.3
const VEHICLE_CLEARANCE: float = 1.5
const PERSONAL_SPACE: float = 1.4
const HARD_SEPARATION: float = 0.72 # Wider than two 0.32m collision radii.
const SIDESTEP_DISTANCE: float = 1.4
const SIDESTEP_SPEED: float = 1.5
var _sidestep_offsets: Array[float] = []
var _blocked_frames: Array[int] = []

func configure_traffic(signals: CivicTrafficSignalController, spawner: CivicTrafficSpawner, reservations: CivicIntersectionReservations = null) -> void:
    _signal_controller = signals
    _traffic_spawner = spawner
    _reservations = reservations

func _ready() -> void:
    var shirt_colors := [
        Color(0.82, 0.29, 0.24),
        Color(0.20, 0.53, 0.77),
        Color(0.31, 0.62, 0.39),
        Color(0.82, 0.66, 0.23)
    ]
    for index in range(pedestrian_count):
        var walker := AnimatableBody3D.new()
        walker.collision_layer = 8
        walker.collision_mask = 0 # Sensing layer only; no rigid actor-actor collision.
        walker.sync_to_physics = true
        walker.set_meta("pedestrian_index", index)
        var collider := CollisionShape3D.new()
        collider.name = "BodyCollision"
        var capsule := CapsuleShape3D.new()
        capsule.radius = BODY_RADIUS
        capsule.height = 1.75
        collider.shape = capsule
        collider.position.y = 0.87
        walker.add_child(collider)
        walker.name = "Pedestrian_%02d" % index
        add_child(walker)
        var color: Color = shirt_colors[index % shirt_colors.size()]
        _part(walker, "Torso", Vector3(0, 1.18, 0), Vector3(0.42, 0.62, 0.26), color)
        _part(walker, "Head", Vector3(0, 1.72, 0), Vector3(0.31, 0.33, 0.31), Color(0.70, 0.46, 0.31))
        var left_arm := _part(walker, "LeftArm", Vector3(-0.31, 1.13, 0), Vector3(0.15, 0.59, 0.18), color)
        var right_arm := _part(walker, "RightArm", Vector3(0.31, 1.13, 0), Vector3(0.15, 0.59, 0.18), color)
        var left_leg := _part(walker, "LeftLeg", Vector3(-0.12, 0.45, 0), Vector3(0.17, 0.78, 0.19), Color(0.17, 0.21, 0.28))
        var right_leg := _part(walker, "RightLeg", Vector3(0.12, 0.45, 0), Vector3(0.17, 0.78, 0.19), Color(0.17, 0.21, 0.28))
        # Search an unoccupied start; overlapping capsules cannot resolve
        # themselves through simple stop-on-obstacle avoidance.
        var spawn_progress: float = float(index) * 5.0
        var loop_length: float = district_extent * 1.65
        var found_spawn: bool = false
        for attempt in range(192):
            var spawn_fraction: float = fposmod(spawn_progress, loop_length) - loop_length * 0.5
            if _spawn_is_clear(_walk_position(index % 4, spawn_fraction)):
                found_spawn = true
                break
            spawn_progress += PERSONAL_SPACE + 0.3
        if not found_spawn:
            push_warning("Pedestrian spawn skipped: all safe slots occupied (%d)" % index)
            walker.queue_free()
            continue
        _walker_progress.append(spawn_progress)
        _sidestep_offsets.append(0.0)
        _blocked_frames.append(0)
        _crossing.append(false)
        walker.position = _walk_position(index % 4, fposmod(spawn_progress, loop_length) - loop_length * 0.5)
        _walkers.append({
            "root": walker, "arms": [left_arm, right_arm], "legs": [left_leg, right_leg],
            "phase": float(index) * 1.7, "speed": 1.0 + float(index % 3) * 0.22,
            "side": index % 4, "offset": float(index) * 5.0
        })

func _part(parent: Node3D, part_name: String, position_value: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    part.position = position_value
    if part_name == "Head":
        var head_mesh := SphereMesh.new()
        head_mesh.radius = size.x * 0.5
        head_mesh.height = size.y
        part.mesh = head_mesh
    else:
        var limb_mesh := CapsuleMesh.new()
        limb_mesh.radius = minf(size.x, size.z) * 0.5
        limb_mesh.height = maxf(size.y, limb_mesh.radius * 2.0)
        part.mesh = limb_mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    part.material_override = material
    parent.add_child(part)
    return part

func _physics_process(delta: float) -> void:
    if delta <= 0.0:
        return
    _elapsed += delta
    var length: float = district_extent * 1.65
    for index in range(_walkers.size()):
        var data: Dictionary = _walkers[index]
        var root: Node3D = data["root"]
        var side: int = data["side"]
        var speed: float = data["speed"]
        var old_progress: float = fposmod(_walker_progress[index], length) - length * 0.5
        var proposed: float = fposmod(_walker_progress[index] + delta * speed, length) - length * 0.5
        var can_walk: bool = true
        # Safety recovery is independent of traffic-light permission. A walker
        # at a red crossing must still move away from an overlapping player.
        var recovering: bool = _resolve_actor_overlap(index, delta)
        if not _crossing[index] and old_progress < -6.0 and proposed >= -6.0:
            if _can_cross(side) and _reserve_crossing(index, side):
                _crossing[index] = true
            else:
                _walker_progress[index] = -6.0 + length * 0.5
                can_walk = false
        elif not _crossing[index] and absf(old_progress + 6.0) < 0.0001:
            if _can_cross(side) and _reserve_crossing(index, side):
                _crossing[index] = true
            else:
                can_walk = false
        if recovering or _yield_to_player(index, delta):
            can_walk = false
        elif can_walk:
            can_walk = _advance_clear_walker(index, delta, length)
        if can_walk:
            _blocked_frames[index] = 0
        else:
            _blocked_frames[index] += 1
        var progress: float = fposmod(_walker_progress[index], length) - length * 0.5
        if _crossing[index] and progress >= 6.0:
            _release_crossing(index, side)
            _crossing[index] = false
        # Position was accepted by _advance_clear_walker; when blocked, the
        # body either sidesteps into tested space or stays in place.
        match side:
            0:
                root.rotation.y = PI
            1:
                root.rotation.y = 0.0
            2:
                root.rotation.y = -PI * 0.5
            3:
                root.rotation.y = PI * 0.5
        var swing: float = sin(_elapsed * speed * 7.0 + data["phase"]) * 0.35 if can_walk else 0.0
        var arms: Array = data["arms"]
        var legs: Array = data["legs"]
        arms[0].rotation.x = swing
        arms[1].rotation.x = -swing
        legs[0].rotation.x = -swing
        legs[1].rotation.x = swing

## When somebody is already embedded, create small local separation.
## A separate fallback is needed because planning from overlapping positions
## cannot know a legal path until the initial penetration is reduced.
func _resolve_actor_overlap(index: int, delta: float) -> bool:
    var walker: Node3D = _walkers[index]["root"]
    var danger_position: Vector3 = Vector3.ZERO
    var nearest_distance: float = INF
    var nearest_minimum: float = HARD_SEPARATION
    var player: Node3D = get_parent().get_node_or_null("PlayerRoot") as Node3D
    if player != null:
        var player_gap := Vector2(walker.global_position.x - player.global_position.x, walker.global_position.z - player.global_position.z).length()
        if player_gap < PLAYER_CLEARANCE:
            nearest_distance = player_gap
            nearest_minimum = PLAYER_CLEARANCE
            danger_position = to_local(player.global_position)
    for other_index in range(_walkers.size()):
        if other_index == index:
            continue
        var other: Node3D = _walkers[other_index]["root"]
        var gap := Vector2(walker.position.x - other.position.x, walker.position.z - other.position.z).length()
        if gap < HARD_SEPARATION and (nearest_distance == INF or (gap / HARD_SEPARATION) < (nearest_distance / nearest_minimum)):
            nearest_distance = gap
            nearest_minimum = HARD_SEPARATION
            danger_position = other.position
    if nearest_distance == INF:
        return false
    var away: Vector3 = walker.position - danger_position
    away.y = 0.0
    if away.length_squared() < 0.0001:
        var angle: float = float((index * 19 + 7) % 8) * PI / 4.0
        away = Vector3(cos(angle), 0.0, sin(angle))
    away = away.normalized()
    var correction: float = minf(maxf(0.08, nearest_minimum - nearest_distance + 0.05), 0.36)
    var before: Vector3 = walker.position
    for trial in [away, away.rotated(Vector3.UP, PI / 3.0), away.rotated(Vector3.UP, -PI / 3.0)]:
        var destination: Vector3 = before + trial * correction
        if _candidate_is_clear(index, before, destination, false):
            walker.position = destination
            var data: Dictionary = _walkers[index]
            var side: int = data["side"]
            var loop_length: float = district_extent * 1.65
            var route_progress: float = fposmod(_walker_progress[index], loop_length) - loop_length * 0.5
            var center: Vector3 = _walk_position(side, route_progress)
            _sidestep_offsets[index] = clampf(
                (destination - center).dot(_walker_right(side, float(data["speed"]))),
                -2.2, 2.2
            )
            return true
    return false

## People have right-of-way over an NPC's route. Approach is sensed before
## they touch; a pedestrian moves sideways instead of physically pushing the
## player or remaining motionless in front of them.
func _yield_to_player(index: int, delta: float) -> bool:
    var player: Node3D = get_parent().get_node_or_null("PlayerRoot") as Node3D
    if player == null:
        return false
    var root: Node3D = _walkers[index]["root"]
    var to_player: Vector3 = player.global_position - root.global_position
    to_player.y = 0.0
    if to_player.length_squared() >= PLAYER_YIELD_RADIUS * PLAYER_YIELD_RADIUS:
        return false
    var entry: Dictionary = _walkers[index]
    var side: int = entry["side"]
    var speed: float = entry["speed"]
    var loop_length: float = district_extent * 1.65
    var progress: float = fposmod(_walker_progress[index], loop_length) - loop_length * 0.5
    var center: Vector3 = _walk_position(side, progress)
    var lateral: Vector3 = _walker_right(side, speed)
    var player_local: Vector3 = to_local(player.global_position)
    var player_side: float = (player_local - center).dot(lateral)
    var direction: float = -1.0 if player_side > 0.0 else 1.0
    for sign_value in [direction, -direction]:
        var new_offset: float = move_toward(
            _sidestep_offsets[index],
            sign_value * SIDESTEP_DISTANCE,
            PLAYER_YIELD_SPEED * delta
        )
        var candidate: Vector3 = center + lateral * new_offset
        var previous: Vector3 = root.position
        var old_gap: Vector3 = previous - player_local
        var new_gap: Vector3 = candidate - player_local
        old_gap.y = 0.0
        new_gap.y = 0.0
        if new_gap.length_squared() + 0.00001 < old_gap.length_squared():
            continue
        if _candidate_is_clear(index, previous, candidate, false):
            root.position = candidate
            _sidestep_offsets[index] = new_offset
            return true
    # When the player occupies the walkway, wait rather than walk into them.
    return true

## Spawn and route-reset clearance are checked against already committed
## pedestrian positions, never the unoccupied route centerline alone.
func _spawn_is_clear(candidate: Vector3) -> bool:
    for entry in _walkers:
        var other: Node3D = entry["root"]
        var delta: Vector3 = other.position - candidate
        delta.y = 0.0
        if delta.length_squared() < PERSONAL_SPACE * PERSONAL_SPACE:
            return false
    var player: Node3D = get_parent().get_node_or_null("PlayerRoot") as Node3D
    if player != null:
        var offset: Vector3 = player.global_position - to_global(candidate)
        offset.y = 0.0
        if offset.length_squared() < PLAYER_CLEARANCE * PLAYER_CLEARANCE:
            return false
    return true

## The lane-relative right side is opposite for opposing walkers; deterministic
## yielding avoids both agents choosing the same physical passing side.
func _walker_right(side: int, speed: float) -> Vector3:
    var forward := Vector3.FORWARD
    match side:
        0:
            forward = Vector3.BACK
        1:
            forward = Vector3.FORWARD
        2:
            forward = Vector3.RIGHT
        3:
            forward = Vector3.LEFT
    if speed < 0.0:
        forward = -forward
    return Vector3(forward.z, 0.0, -forward.x)

func _advance_clear_walker(index: int, delta: float, loop_length: float) -> bool:
    var data: Dictionary = _walkers[index]
    var root: Node3D = data["root"]
    var side: int = data["side"]
    var speed: float = data["speed"]
    var previous: Vector3 = root.position
    var progress: float = fposmod(_walker_progress[index], loop_length) - loop_length * 0.5
    var next_progress: float = fposmod(_walker_progress[index] + speed * delta, loop_length) - loop_length * 0.5
    var lateral := _walker_right(side, speed)
    var center: Vector3 = _walk_position(side, next_progress)
    var wraps: bool = previous.distance_squared_to(center) > 4.0
    var recenter: float = move_toward(_sidestep_offsets[index], 0.0, SIDESTEP_SPEED * delta)
    var intended: Vector3 = center + lateral * recenter
    if _candidate_is_clear(index, previous, intended, wraps):
        root.position = intended
        _sidestep_offsets[index] = recenter
        _walker_progress[index] += delta * speed
        return true
    # Route wrap is a safe respawn, never a swept movement across the city.
    # Wait for destination clearance rather than teleport into another walker.
    if wraps:
        return false
    # Alternate the passing side after sustained obstruction. Test the
    # lateral path first; never step through another agent to reach an offset.
    var first_side: float = 1.0 if _blocked_frames[index] < 75 else -1.0
    for sign_value in [first_side, -first_side]:
        var shifted: float = move_toward(
            _sidestep_offsets[index], sign_value * SIDESTEP_DISTANCE,
            SIDESTEP_SPEED * delta
        )
        if absf(shifted - _sidestep_offsets[index]) < 0.00001:
            continue
        var alongside: Vector3 = center + lateral * shifted
        if _candidate_is_clear(index, previous, alongside, false):
            root.position = alongside
            _sidestep_offsets[index] = shifted
            _walker_progress[index] += delta * speed
            return true
        # Controlled side-only movement allows the agent to go around an
        # obstacle without advancing through the occupied crossing.
        var sideways: Vector3 = _walk_position(side, progress) + lateral * shifted
        if _candidate_is_clear(index, previous, sideways, false):
            root.position = sideways
            _sidestep_offsets[index] = shifted
            return false
    return false

func _candidate_is_clear(index: int, previous: Vector3, destination: Vector3, wraps: bool) -> bool:
    if _pedestrian_blocked(index, destination):
        return false
    if not wraps and _walker_path_occupied(index, previous, destination):
        return false
    # Probe solid buildings/props and vehicles only. Agent personal space
    # and yielding are handled separately from the physics query.
    if _swept_path_blocked(index, previous, destination, wraps):
        return false
    return true

func _walk_position(side: int, progress: float) -> Vector3:
    var offset: float = 5.0
    match side:
        0:
            return Vector3(offset, 0.23, progress)
        1:
            return Vector3(-offset, 0.23, -progress)
        2:
            return Vector3(progress, 0.23, offset)
        _:
            return Vector3(-progress, 0.23, -offset)

## A moving pedestrian must not cross another pedestrian's occupied space.
## Segment sampling also catches perpendicular routes at the junction.
func _walker_path_occupied(index: int, start: Vector3, destination: Vector3) -> bool:
    for other_index in range(_walkers.size()):
        if other_index == index:
            continue
        var other: Node3D = _walkers[other_index]["root"]
        var initial: Vector3 = start - other.position
        var proposed: Vector3 = destination - other.position
        initial.y = 0.0
        proposed.y = 0.0
        var initial_squared: float = initial.length_squared()
        var proposed_squared: float = proposed.length_squared()
        # Never cross the combined collision capsules, even with large steps.
        if _segment_near_point(start, destination, other.position, HARD_SEPARATION):
            if initial_squared >= HARD_SEPARATION * HARD_SEPARATION or proposed_squared <= initial_squared + 0.000001:
                return true
        # In the personal-space buffer, only outward/parallel movement is
        # permitted. This lets a pedestrian sidestep out of a tight crowd.
        if _segment_near_point(start, destination, other.position, PERSONAL_SPACE):
            if proposed_squared < initial_squared - 0.000001:
                return true
    return false

static func _segment_near_point(start: Vector3, destination: Vector3, point: Vector3, clearance: float) -> bool:
    var travel: Vector3 = destination - start
    travel.y = 0.0
    var relative: Vector3 = point - start
    relative.y = 0.0
    var fraction: float = clampf(relative.dot(travel) / maxf(travel.length_squared(), 0.000001), 0.0, 1.0)
    var gap: Vector3 = relative - travel * fraction
    return gap.length_squared() < clearance * clearance

func _pedestrian_blocked(index: int, next_position: Vector3) -> bool:
    var current: Vector3 = _walkers[index]["root"].position
    var player: Node3D = get_parent().get_node_or_null("PlayerRoot") as Node3D
    if player != null:
        var destination_gap: Vector3 = player.global_position - to_global(next_position)
        var current_gap: Vector3 = player.global_position - to_global(current)
        destination_gap.y = 0.0
        current_gap.y = 0.0
        if destination_gap.length_squared() < PLAYER_CLEARANCE * PLAYER_CLEARANCE:
            if destination_gap.length_squared() < current_gap.length_squared() - 0.000001:
                return true
    for other_index in range(_walkers.size()):
        if other_index == index:
            continue
        var other: Node3D = _walkers[other_index]["root"]
        var destination_gap: Vector3 = other.position - next_position
        var current_gap: Vector3 = other.position - current
        destination_gap.y = 0.0
        current_gap.y = 0.0
        if destination_gap.length_squared() < WALKER_CLEARANCE * WALKER_CLEARANCE:
            if destination_gap.length_squared() < current_gap.length_squared() - 0.000001:
                return true
    if _traffic_spawner != null:
        for vehicle in _traffic_spawner.active_vehicles:
            if not is_instance_valid(vehicle) or not vehicle.active:
                continue
            var candidate_gap: Vector3 = vehicle.global_position - to_global(next_position)
            var existing_gap: Vector3 = vehicle.global_position - to_global(current)
            candidate_gap.y = 0.0
            existing_gap.y = 0.0
            if candidate_gap.length_squared() < VEHICLE_CLEARANCE * VEHICLE_CLEARANCE:
                if candidate_gap.length_squared() < existing_gap.length_squared() - 0.000001:
                    return true
    return false

func _swept_path_blocked(index: int, from_position: Vector3, to_position: Vector3, wraps: bool = false) -> bool:
    var walker: AnimatableBody3D = _walkers[index]["root"] as AnimatableBody3D
    var collider: CollisionShape3D = walker.get_node("BodyCollision") as CollisionShape3D
    if collider.shape == null:
        return true
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = collider.shape
    query.collision_mask = 1 | 4 # Solid city/vehicles only; people handled with personal-space rules.
    query.exclude = [walker.get_rid()]
    query.margin = 0.015
    var distance: float = (to_position - from_position).length()
    var samples: int = 1 if wraps else maxi(1, int(ceil(distance / 0.2)))
    for sample in range(1, samples + 1):
        var fraction: float = float(sample) / float(samples)
        var trial: Vector3 = to_position if wraps else from_position.lerp(to_position, fraction)
        query.transform = Transform3D(
            walker.global_transform.basis,
            to_global(trial) + Vector3.UP * collider.position.y
        )
        var contacts: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 16)
        for hit in contacts:
            var obstacle := hit.get("collider") as CollisionObject3D
            if obstacle == null:
                continue
            if (obstacle.collision_layer & 4) != 0:
                return true # Solid vehicle.
            # Roads, terrain and sidewalks are floor surfaces, not obstacles.
            # A capsule grazing their top surface must not freeze the NPC.
            var obstacle_shape := obstacle.get_node_or_null("CollisionShape3D") as CollisionShape3D
            if obstacle_shape != null and obstacle_shape.shape is BoxShape3D:
                var box: BoxShape3D = obstacle_shape.shape as BoxShape3D
                var floor_top: float = obstacle_shape.global_position.y + box.size.y * 0.5
                if floor_top <= to_global(trial).y + 0.04:
                    continue
            return true
    return false

func _can_cross(side: int) -> bool:
    if _signal_controller == null:
        return true
    # Pedestrians cross only while the parallel vehicle axis is stopped.
    var approach: String = "E" if side < 2 else "N"
    if _signal_controller.aspect_for_approach(approach) != "red":
        return false
    if _traffic_spawner == null:
        return true
    for vehicle in _traffic_spawner.active_vehicles:
        if not is_instance_valid(vehicle) or not vehicle.active:
            continue
        if vehicle.global_position.distance_to(Vector3.ZERO) < 7.0:
            return false
    return true

func _crossing_zone(side: int) -> String:
    return "pedestrian_crossing_ew" if side < 2 else "pedestrian_crossing_ns"

func _reserve_crossing(index: int, side: int) -> bool:
    if _reservations == null:
        return true
    var pedestrian_id: int = 100000 + index
    var zone: String = _crossing_zone(side)
    var start_tick: int = _reservations.current_tick
    var result: Dictionary = _reservations.request(pedestrian_id, PackedStringArray([zone]), start_tick, start_tick + 600)
    if not bool(result.get("granted", false)):
        return false
    if not _reservations.occupy(pedestrian_id, zone):
        _reservations.cancel(pedestrian_id)
        return false
    return true

func _release_crossing(index: int, side: int) -> void:
    if _reservations == null:
        return
    var pedestrian_id: int = 100000 + index
    _reservations.release(pedestrian_id, _crossing_zone(side))
    _reservations.cancel(pedestrian_id)

func _exit_tree() -> void:
    for index in range(_crossing.size()):
        if _crossing[index]:
            _release_crossing(index, index % 4)
