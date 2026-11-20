class_name CivicNeighborhoodDetails
extends RefCounted
## WORLD-001D: deterministic, low-poly presentation-only street identity.
## No traffic permission, missions, topology or save data are modified.
## Only non-colliding visuals; building support and roads stay authoritative.

static func build(parent: Node3D) -> void:
    if parent == null:
        return
    _marketfront(parent)
    _bus_stop(parent)
    _parking_court(parent)
    _park_identity(parent)
    _street_lighting(parent)

static func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = roughness
    return result

static func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3,
        material: StandardMaterial3D) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    mesh.mesh = BoxMesh.new()
    (mesh.mesh as BoxMesh).size = size
    mesh.position = pos
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)
    return mesh

static func _text(parent: Node3D, name: String, caption: String,
        at: Vector3, scale_factor: float = 0.005) -> void:
    var label := Label3D.new()
    label.name = name
    label.text = caption
    label.font_size = 34
    label.pixel_size = scale_factor
    label.position = at
    label.modulate = Color(0.96, 0.95, 0.86)
    label.no_depth_test = false
    parent.add_child(label)

static func _marketfront(parent: Node3D) -> void:
    var group := Node3D.new()
    group.name = "MarketStreetIdentity"
    parent.add_child(group)
    var awnings := [_material(Color(0.78, 0.28, 0.23)),
        _material(Color(0.16, 0.47, 0.57)),
        _material(Color(0.91, 0.63, 0.20)),
        _material(Color(0.41, 0.52, 0.36))]
    var trim := _material(Color(0.26, 0.29, 0.33))
    # Decorative frontage signs attach to actual existing building bodies.
    # Their world positions are derived from building transforms, rather
    # than placing more collidable boxes on roads or pedestrian paths.
    for i in range(4):
        var building: Node3D = parent.get_node_or_null("OuterBuilding_%d_%d" %
            [i, i]) as Node3D
        if building == null:
            continue
        var facade := Node3D.new()
        facade.name = "LocalShopFront"
        building.add_child(facade)
        var body := building.get_node_or_null("MeshInstance3D") as MeshInstance3D
        var dimensions := Vector3(10.0, 8.0, 10.0)
        if body != null and body.mesh is BoxMesh:
            dimensions = (body.mesh as BoxMesh).size
        var front_z: float = -dimensions.z * 0.5 - 0.18
        _box(facade, "Awning", Vector3(0, -dimensions.y * 0.5 + 2.7, front_z - 0.35),
            Vector3(minf(5.8, dimensions.x - 1.0), 0.14, 0.72),
            awnings[i])
        _box(facade, "ShopSign", Vector3(0, -dimensions.y * 0.5 + 3.5, front_z),
            Vector3(minf(5.6, dimensions.x - 1.0), 0.7, 0.13), trim)
        _text(facade, "ShopName", ["NAGRIPUR MART", "CHAI CORNER",
            "FRESH PRODUCE", "LOCAL REPAIRS"][i],
            Vector3(0, -dimensions.y * 0.5 + 3.5, front_z - 0.085), 0.005)

static func _bus_stop(parent: Node3D) -> void:
    var group := Node3D.new()
    group.name = "OldBusStopIdentity"
    # Outside the west approach roadway and away from x=-72,z=24
    # building footprint; no physics body is added.
    group.position = Vector3(-92.0, 0.0, 11.0)
    parent.add_child(group)
    var blue := _material(Color(0.18, 0.31, 0.43))
    var cream := _material(Color(0.88, 0.82, 0.63))
    for x in [-2.6, 2.6]:
        _box(group, "ShelterPost_%d" % int(x * 10.0),
            Vector3(x, 1.6, 0), Vector3(0.13, 3.2, 0.13), blue)
    _box(group, "ShelterRoof", Vector3(0, 3.22, 0),
        Vector3(6.0, 0.17, 2.1), cream)
    _box(group, "BenchSeat", Vector3(0, 0.66, 0.3),
        Vector3(3.2, 0.13, 0.65), blue)
    _box(group, "RouteBoard", Vector3(0, 2.5, 0.1),
        Vector3(3.8, 0.56, 0.11), blue)
    _text(group, "RouteCaption", "OLD BUS STOP",
        Vector3(0, 2.50, 0.035))

static func _parking_court(parent: Node3D) -> void:
    var group := Node3D.new()
    group.name = "ParkingCourtIdentity"
    group.position = Vector3(95.0, 0.0, 92.0)
    parent.add_child(group)
    var surface := _material(Color(0.26, 0.31, 0.30))
    var paint := _material(Color(0.87, 0.82, 0.62))
    # Small walkable visual plaza between existing building blocks.
    # Does not overlap 8m-wide roads at x,z=120 or x,z=46.
    _box(group, "ParkingSurface", Vector3(0, 0.039, 0),
        Vector3(21.0, 0.015, 17.0), surface)
    for i in range(4):
        var x: float = -7.5 + float(i) * 5.0
        _box(group, "BayStripe_%d" % i, Vector3(x, 0.052, 0),
            Vector3(0.12, 0.02, 14.0), paint)
    _text(group, "ParkingLabel", "PUBLIC PARKING",
        Vector3(0, 1.2, -8.4), 0.006)

static func _park_identity(parent: Node3D) -> void:
    var park: Node3D = parent.get_node_or_null("CommunityPark") as Node3D
    if park == null:
        return
    var group := Node3D.new()
    group.name = "ParkIdentity"
    park.add_child(group)
    var green := _material(Color(0.22, 0.43, 0.28))
    var earth := _material(Color(0.46, 0.32, 0.22))
    for offset in [Vector3(-8, 0, -7), Vector3(8, 0, -6),
            Vector3(-7, 0, 7), Vector3(7, 0, 7)]:
        _box(group, "TreeTrunk", offset + Vector3.UP * 1.3,
            Vector3(0.4, 2.6, 0.4), earth)
        var crown := MeshInstance3D.new()
        crown.name = "TreeCrown"
        crown.mesh = SphereMesh.new()
        (crown.mesh as SphereMesh).radius = 1.9
        (crown.mesh as SphereMesh).height = 3.2
        crown.position = offset + Vector3.UP * 3.6
        crown.material_override = green
        crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        group.add_child(crown)
    _text(group, "ParkCaption", "COMMUNITY PARK", Vector3(0, 1.9, -9.8))

static func _street_lighting(parent: Node3D) -> void:
    var group := Node3D.new()
    group.name = "StreetIdentityLighting"
    parent.add_child(group)
    var metal := _material(Color(0.31, 0.34, 0.34))
    var lamp := _material(Color(0.94, 0.85, 0.56), 0.35)
    # Visual-only fixtures on the outer approach; no new street collisions.
    for i in range(4):
        var x: float = -93.0 + float(i) * 62.0
        var z: float = 13.0 if i % 2 == 0 else -13.0
        var fixture := Node3D.new()
        fixture.name = "StreetLamp_%d" % i
        fixture.position = Vector3(x, 0, z)
        group.add_child(fixture)
        _box(fixture, "Pole", Vector3(0, 2.65, 0),
            Vector3(0.13, 5.3, 0.13), metal)
        _box(fixture, "LampCap", Vector3(0, 5.3, 0),
            Vector3(0.85, 0.23, 0.65), lamp)
