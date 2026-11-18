class_name CivicRideableBike
extends StaticBody3D
## VEHICLE-RIDE-01: a physical-looking, reusable player motorcycle.
## Only the rider's collision-aware CharacterBody moves in ride mode;
## the interactable body is disabled while attached to that rider.
const MOUNT_DISTANCE_M: float = 2.8
var rider: Node3D
var home_parent: Node
var _wheel_front: MeshInstance3D
var _wheel_rear: MeshInstance3D
var _ride_label: Label3D

func _ready() -> void:
    collision_layer = 16
    collision_mask = 0
    _make_visuals()

func _part(part_name: String, dimensions: Vector3, at: Vector3,
        color: Color) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = part_name
    var block := BoxMesh.new()
    block.size = dimensions
    mesh.mesh = block
    mesh.position = at
    var paint := StandardMaterial3D.new()
    paint.albedo_color = color
    paint.metallic = 0.18
    paint.roughness = 0.65
    mesh.material_override = paint
    add_child(mesh)
    return mesh

func _wheel(part_name: String, at: Vector3) -> MeshInstance3D:
    var wheel := MeshInstance3D.new()
    wheel.name = part_name
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.43
    cylinder.bottom_radius = 0.43
    cylinder.height = 0.24
    wheel.mesh = cylinder
    wheel.position = at
    wheel.rotation.z = PI * 0.5
    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color(0.09, 0.11, 0.12)
    wheel.material_override = rubber
    add_child(wheel)
    # A visible radial spoke makes the rolling direction readable.
    # The CylinderMesh axle is LOCAL Y (tilted onto the bike's X axis).
    # Children follow the wheel's LOCAL axial spin automatically.
    var spoke := MeshInstance3D.new()
    spoke.name = "RollingSpoke"
    var spoke_mesh := BoxMesh.new()
    spoke_mesh.size = Vector3(0.055, 0.27, 0.32)
    spoke.mesh = spoke_mesh
    spoke.position = Vector3(0.0, 0.0, -0.19)
    var spoke_paint := StandardMaterial3D.new()
    spoke_paint.albedo_color = Color(0.78, 0.82, 0.84)
    spoke.material_override = spoke_paint
    wheel.add_child(spoke)
    return wheel

func _make_visuals() -> void:
    var shape := CollisionShape3D.new()
    shape.name = "InteractionShape"
    shape.position = Vector3(0, 0.85, 0)
    var box := BoxShape3D.new()
    box.size = Vector3(1.0, 1.35, 1.8)
    shape.shape = box
    add_child(shape)

    _wheel_front = _wheel("FrontWheel", Vector3(0, 0.43, -0.95))
    _wheel_rear = _wheel("RearWheel", Vector3(0, 0.43, 0.85))
    _part("Chassis", Vector3(0.26, 0.30, 1.62), Vector3(0, 0.84, 0),
        Color(0.12, 0.18, 0.24))
    _part("FuelTank", Vector3(0.58, 0.42, 0.82), Vector3(0, 1.10, -0.23),
        Color(0.83, 0.18, 0.13))
    _part("Seat", Vector3(0.56, 0.16, 0.82), Vector3(0, 1.18, 0.40),
        Color(0.09, 0.10, 0.12))
    _part("Fork", Vector3(0.14, 0.95, 0.14), Vector3(0, 0.89, -0.94),
        Color(0.64, 0.69, 0.71))
    _part("Handlebar", Vector3(0.95, 0.10, 0.14), Vector3(0, 1.53, -0.91),
        Color(0.20, 0.23, 0.25))
    _part("Headlight", Vector3(0.36, 0.27, 0.15), Vector3(0, 1.13, -1.05),
        Color(1.0, 0.94, 0.62))
    _part("TailLight", Vector3(0.40, 0.15, 0.12), Vector3(0, 0.98, 1.05),
        Color(1.0, 0.12, 0.07))
    _ride_label = Label3D.new()
    _ride_label.name = "BikeHint"
    _ride_label.text = "BIKE\nE / USE TO RIDE"
    _ride_label.font_size = 38
    _ride_label.pixel_size = 0.006
    _ride_label.position = Vector3(0, 2.2, 0)
    add_child(_ride_label)

func interact(actor: Node) -> void:
    if rider != null or not (actor is Node3D) or not actor.has_method("mount_bike"):
        return
    var player := actor as Node3D
    if player.global_position.distance_to(global_position) > MOUNT_DISTANCE_M:
        if player.has_signal("interaction_message"):
            player.emit_signal("interaction_message", "Move closer to the bike.")
        return
    player.call("mount_bike", self)

func mount_to(player: Node3D) -> bool:
    if rider != null or player == null or not is_inside_tree():
        return false
    home_parent = get_parent()
    rider = player
    reparent(player)
    position = Vector3.ZERO
    rotation = Vector3.ZERO
    collision_layer = 0
    if is_instance_valid(_ride_label):
        _ride_label.visible = false
    return true

func park() -> bool:
    if rider == null or not is_instance_valid(home_parent):
        return false
    # Keep real location, not an invented spawn or road junction.
    reparent(home_parent)
    collision_layer = 16
    rider = null
    if is_instance_valid(_ride_label):
        _ride_label.visible = true
    return true

func animate_wheels(distance_m: float) -> void:
    if not is_finite(distance_m) or absf(distance_m) <= 0.000001:
        return
    var angular_distance: float = distance_m / 0.43
    # Cylinders were tilted by PI/2 around Z in _wheel(), so their
    # spin axle is the cylinder's LOCAL Y axis (world/bike X).
    # rotate_y() applies a parent-space yaw and makes them swivel flat.
    # rotate_object_local() spins around the actual wheel axle instead.
    if is_instance_valid(_wheel_front):
        _wheel_front.rotate_object_local(Vector3.UP, angular_distance)
    if is_instance_valid(_wheel_rear):
        _wheel_rear.rotate_object_local(Vector3.UP, angular_distance)
