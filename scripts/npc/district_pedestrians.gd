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
const PLAYER_CLEARANCE: float = 1.15
const WALKER_CLEARANCE: float = 1.05
const CROSSING_CLEARANCE: float = 1.3
const VEHICLE_CLEARANCE: float = 1.5

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
        walker.collision_mask = 1 | 2 | 4 | 8
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
        _walker_progress.append(float(index) * 5.0)
        _crossing.append(false)
        walker.position = _walk_position(index % 4, fposmod(_walker_progress[index], district_extent * 1.65) - district_extent * 1.65 * 0.5)
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
        var current_position: Vector3 = root.position
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
        if can_walk:
            var next_progress: float = fposmod(_walker_progress[index] + delta * speed, length) - length * 0.5
            var proposed_position: Vector3 = _walk_position(side, next_progress)
            var is_wrap: bool = current_position.distance_squared_to(proposed_position) > 4.0
            if _pedestrian_blocked(index, proposed_position) or _walker_path_occupied(index, current_position, proposed_position) or (not is_wrap and _swept_path_blocked(index, current_position, proposed_position)):
                can_walk = false
            else:
                _walker_progress[index] += delta * speed
        var progress: float = fposmod(_walker_progress[index], length) - length * 0.5
        if _crossing[index] and progress >= 6.0:
            _release_crossing(index, side)
            _crossing[index] = false
        var target_position: Vector3 = _walk_position(side, progress)
        # Never teleport a pedestrian through another actor when the route wraps.
        # A blocked pedestrian stays exactly where it was last frame.
        if can_walk:
            root.position = target_position
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
    var travel: Vector3 = destination - start
    travel.y = 0.0
    # At route wrap, test only destination occupancy (not the teleport path).
    if travel.length_squared() > 4.0:
        return false
    for other_index in range(_walkers.size()):
        if other_index == index:
            continue
        var other: Node3D = _walkers[other_index]["root"]
        var relative: Vector3 = other.position - start
        relative.y = 0.0
        var fraction: float = clampf(relative.dot(travel) / maxf(travel.length_squared(), 0.000001), 0.0, 1.0)
        var closest: Vector3 = start + travel * fraction
        var gap: Vector3 = other.position - closest
        gap.y = 0.0
        if gap.length_squared() < CROSSING_CLEARANCE * CROSSING_CLEARANCE:
            return true
    return false

func _pedestrian_blocked(index: int, next_position: Vector3) -> bool:
    # Evaluate current and proposed positions so a walker cannot step into
    # a player already overlapping its path.
    var player: Node3D = get_parent().get_node_or_null("PlayerRoot") as Node3D
    if player != null:
        for candidate in [_walkers[index]["root"].position, next_position]:
            var delta_to_player: Vector3 = player.global_position - to_global(candidate)
            delta_to_player.y = 0.0
            if delta_to_player.length_squared() < PLAYER_CLEARANCE * PLAYER_CLEARANCE:
                return true
    for other_index in range(_walkers.size()):
        if other_index == index:
            continue
        var other: Node3D = _walkers[other_index]["root"]
        var separation: Vector3 = other.position - next_position
        separation.y = 0.0
        if separation.length_squared() < WALKER_CLEARANCE * WALKER_CLEARANCE:
            return true
    if _traffic_spawner != null:
        for vehicle in _traffic_spawner.active_vehicles:
            if not is_instance_valid(vehicle) or not vehicle.active:
                continue
            var delta_to_vehicle: Vector3 = vehicle.global_position - to_global(next_position)
            delta_to_vehicle.y = 0.0
            if delta_to_vehicle.length_squared() < VEHICLE_CLEARANCE * VEHICLE_CLEARANCE:
                return true
    return false

func _swept_path_blocked(index: int, from_position: Vector3, to_position: Vector3) -> bool:
    var movement: Vector3 = to_position - from_position
    if movement.length_squared() < 0.000001:
        return false
    var walker: AnimatableBody3D = _walkers[index]["root"] as AnimatableBody3D
    var collider: CollisionShape3D = walker.get_node("BodyCollision") as CollisionShape3D
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = collider.shape
    query.transform = Transform3D(walker.global_transform.basis, to_global(to_position) + Vector3(0.0, collider.position.y, 0.0))
    query.collision_mask = 1 | 2 | 4 | 8
    query.exclude = [walker.get_rid()]
    query.margin = 0.03
    # Keep the capsule clear of the sidewalk top to avoid floor false positives.
    return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

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
