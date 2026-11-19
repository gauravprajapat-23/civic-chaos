class_name CivicCallServiceResponse
extends Node3D
## CALLS-02: one visual municipal response van traveling along the real
## city road graph. This is NOT incident completion, traffic priority,
## an ambulance, or an instant-spawn reward.
signal status_changed(status: String)

const Routes = preload("res://scripts/ui/civic_map_routes.gd")
const SERVICE_SPEED_MPS: float = 5.5
const ARRIVAL_DISTANCE_M: float = 2.5
const SERVICE_ORIGIN: Vector3 = Vector3(-46.0, 0.0, -46.0)
const VALID_SERVICES: Dictionary = {
    "civic_litter": "SANITATION",
    "fallen_public_sign": "MAINTENANCE",
    "misplaced_safety_cone": "ROAD SAFETY"
}

var call_id: int = -1
var service_label: String = ""
var target: Vector3 = Vector3.ZERO
var active: bool = false
var arrived: bool = false
var route: PackedVector3Array = PackedVector3Array()
var route_index: int = 1
var _van: StaticBody3D
var _probe: BoxShape3D

func _init() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE

static func service_for(kind: String) -> String:
    return str(VALID_SERVICES.get(kind, ""))

func configure(graph: CivicRoadGraph, incident_id: int, kind: String,
        at: Vector3) -> bool:
    if active or call_id > 0 or graph == null or incident_id <= 0 or (
            not at.is_finite()) or service_for(kind).is_empty() or (
            not is_inside_tree()):
        return false
    _probe = BoxShape3D.new()
    _probe.size = Vector3(1.1, 1.15, 1.9)
    # Public roads may be temporarily occupied. Look for a safe depot
    # departure along existing road nodes, never spawn inside another car.
    var candidate_origins: Array[Vector3] = [
        SERVICE_ORIGIN, Vector3(-46, 0, 0),
        Vector3(0, 0, -46), Vector3(46, 0, -46)
    ]
    var points := PackedVector3Array()
    var spawn := Vector3.ZERO
    for depot in candidate_origins:
        var candidate := Vector3(depot.x, 0.12, depot.z)
        if not _space_clear(candidate, true):
            continue
        var proposed: Dictionary = Routes.plan(graph, depot, at)
        if not bool(proposed.get("ok", false)):
            continue
        var proposed_points: PackedVector3Array = proposed.get(
            "points", PackedVector3Array())
        if proposed_points.size() < 2 or depot.distance_to(at) < ARRIVAL_DISTANCE_M:
            continue
        spawn = candidate
        points = proposed_points
        break
    if points.size() < 2:
        return false
    call_id = incident_id
    service_label = service_for(kind)
    target = at
    route = points
    route_index = 1
    position = spawn
    _build_visual()
    active = true
    status_changed.emit("EN ROUTE")
    return true

func _build_visual() -> void:
    _van = StaticBody3D.new()
    _van.name = "MunicipalServiceVehicle"
    _van.collision_layer = 4
    _van.collision_mask = 0
    add_child(_van)
    var collider := CollisionShape3D.new()
    collider.name = "CollisionShape3D"
    collider.shape = _probe
    collider.position.y = 0.7
    _van.add_child(collider)
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.93, 0.73, 0.20)
    paint.metallic = 0.12
    var body := MeshInstance3D.new()
    body.name = "MunicipalServiceVan"
    var box := BoxMesh.new()
    box.size = Vector3(1.15, 0.9, 1.95)
    body.mesh = box
    body.position.y = 0.75
    body.material_override = paint
    _van.add_child(body)
    var tire_material := StandardMaterial3D.new()
    tire_material.albedo_color = Color(0.08, 0.09, 0.11)
    for side in [-1.0, 1.0]:
        for axle in [-0.58, 0.58]:
            var wheel := MeshInstance3D.new()
            wheel.name = "Wheel_%d_%d" % [int(side), int(axle * 100)]
            var tire := CylinderMesh.new()
            tire.top_radius = 0.27
            tire.bottom_radius = 0.27
            tire.height = 0.13
            wheel.mesh = tire
            wheel.material_override = tire_material
            wheel.position = Vector3(side * 0.57, 0.35, axle)
            wheel.rotation.z = PI * 0.5
            _van.add_child(wheel)
    var stripe := MeshInstance3D.new()
    stripe.name = "ServiceRoofBeacon"
    var lamp := BoxMesh.new()
    lamp.size = Vector3(0.56, 0.16, 0.32)
    stripe.mesh = lamp
    stripe.position.y = 1.28
    var amber := StandardMaterial3D.new()
    amber.albedo_color = Color(0.99, 0.43, 0.08)
    amber.emission_enabled = true
    amber.emission = amber.albedo_color
    stripe.material_override = amber
    _van.add_child(stripe)
    var label := Label3D.new()
    label.name = "ServiceLabel"
    label.text = service_label
    label.font_size = 30
    label.pixel_size = 0.005
    label.position = Vector3(0, 1.65, 0)
    _van.add_child(label)

## Only actual obstacles at van height block the next step.
## Ground/sidewalk support is below the probe, so no collision bypass
## for walls, traffic, pedestrians, props or mounted motorcycles.
func _space_clear(at: Vector3, spawning: bool = false) -> bool:
    if not is_inside_tree():
        return false
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _probe
    query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.76)
    query.collision_mask = 1 | 2 | 4 | 8 | 16
    if not spawning and is_instance_valid(_van):
        query.exclude = [_van.get_rid()]
    query.margin = 0.03
    return get_world_3d().direct_space_state.intersect_shape(query, 12).is_empty()

func _physics_process(delta: float) -> void:
    if not active or arrived or delta <= 0.0 or route_index >= route.size():
        return
    var waypoint: Vector3 = route[route_index]
    var remaining: Vector3 = Vector3(waypoint.x - position.x, 0,
        waypoint.z - position.z)
    if remaining.length() < 0.20:
        route_index += 1
        if route_index >= route.size():
            arrived = true
            status_changed.emit("ON SCENE")
        return
    var movement: Vector3 = remaining.normalized() * minf(
        remaining.length(), SERVICE_SPEED_MPS * delta)
    var next: Vector3 = position + movement
    if not _space_clear(next):
        return # Traffic and pedestrians retain right of way.
    position = next
    rotation.y = atan2(-movement.x, -movement.z)
    if Vector2(position.x - target.x, position.z - target.z).length() <= ARRIVAL_DISTANCE_M:
        arrived = true
        status_changed.emit("ON SCENE")

func retire() -> void:
    active = false
    queue_free()
