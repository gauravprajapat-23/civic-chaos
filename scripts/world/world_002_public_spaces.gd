class_name CivicWorld002PublicSpaces
extends RefCounted
## WORLD-002B: distinct, non-colliding civic plazas on existing empty lots.
## Visual-only: no road topology, footpath colliders, mission anchors or saves.
const Layout = preload("res://scripts/world/world_002_building_layout.gd")
const PLAZA_CLEARANCE_M: float = 8.0
const PLAZAS := [
    {"id": "northwest", "title": "WEST GARDEN SQUARE",
        "center": Vector3(-93.0, 0.0, -91.0), "size": Vector2(12.0, 11.0),
        "theme": "garden", "color": Color(0.28, 0.48, 0.36)},
    {"id": "southwest", "title": "HERITAGE COURT",
        "center": Vector3(-93.0, 0.0, 92.0), "size": Vector2(11.0, 12.0),
        "theme": "heritage", "color": Color(0.62, 0.43, 0.30)},
    {"id": "northeast", "title": "NEIGHBORHOOD SQUARE",
        "center": Vector3(93.0, 0.0, -92.0), "size": Vector2(12.0, 12.0),
        "theme": "community", "color": Color(0.30, 0.44, 0.62)}
]

static func plots() -> Array[Dictionary]:
    return PLAZAS.duplicate(true)

static func bounds(plot: Dictionary) -> Rect2:
    var at: Vector3 = plot["center"]
    var dimensions: Vector2 = plot["size"]
    return Rect2(Vector2(at.x, at.z) - dimensions * 0.5, dimensions)

static func overlaps(a: Rect2, b: Rect2, clearance: float = 0.0) -> bool:
    return a.grow(clearance).intersects(b)

static func valid_layout() -> bool:
    var seen: Dictionary = {}
    var buildings: Array[Dictionary] = Layout.all_buildings()
    for plot in PLAZAS:
        var key: String = str(plot.get("id", ""))
        var at: Vector3 = plot.get("center", Vector3.INF)
        var dimensions: Vector2 = plot.get("size", Vector2.ZERO)
        if key.is_empty() or seen.has(key) or not at.is_finite() or (
                not dimensions.is_finite() or dimensions.x < 5.0 or dimensions.y < 5.0):
            return false
        seen[key] = true
        var rect: Rect2 = bounds(plot)
        for axis in Layout.AXES:
            if absf(at.x - axis) - dimensions.x * 0.5 < PLAZA_CLEARANCE_M or (
                    absf(at.z - axis) - dimensions.y * 0.5 < PLAZA_CLEARANCE_M):
                return false
        for building in buildings:
            var place: Vector3 = building["center"]
            var size: Vector3 = building["size"]
            var footprint := Rect2(Vector2(place.x, place.z) -
                Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z))
            if overlaps(rect, footprint, 1.0):
                return false
    for a in range(PLAZAS.size()):
        for b in range(a + 1, PLAZAS.size()):
            if overlaps(bounds(PLAZAS[a]), bounds(PLAZAS[b]), 1.0):
                return false
    return seen.size() == 3

static func _material(color: Color) -> StandardMaterial3D:
    var paint := StandardMaterial3D.new()
    paint.albedo_color = color
    paint.roughness = 0.94
    return paint

static func _mesh(parent: Node3D, name: String, at: Vector3,
        size: Vector3, material: Material) -> void:
    var item := MeshInstance3D.new()
    item.name = name
    item.position = at
    var mesh := BoxMesh.new()
    mesh.size = size
    item.mesh = mesh
    item.material_override = material
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)

static func _title(parent: Node3D, caption: String, at: Vector3) -> void:
    var label := Label3D.new()
    label.name = "SquareName"
    label.text = caption
    label.position = at
    label.font_size = 30
    label.pixel_size = 0.006
    label.modulate = Color(0.96, 0.94, 0.86)
    parent.add_child(label)

static func build(parent: Node3D) -> void:
    if parent == null or not valid_layout():
        return
    var group := Node3D.new()
    group.name = "World002PublicSpaces"
    parent.add_child(group)
    for plot in PLAZAS:
        _build_plaza(group, plot)

static func _build_plaza(parent: Node3D, plot: Dictionary) -> void:
    var plaza := Node3D.new()
    plaza.name = "Square_" + str(plot["id"])
    plaza.position = plot["center"]
    parent.add_child(plaza)
    var base := _material(Color(0.50, 0.48, 0.43))
    var accent := _material(plot["color"])
    var stone := _material(Color(0.79, 0.75, 0.66))
    var timber := _material(Color(0.42, 0.27, 0.18))
    var size: Vector2 = plot["size"]
    # A thin floor decal and street furniture: no bodies or colliders.
    # Keep the entire composition inside the validated plot footprint.
    _mesh(plaza, "OpenPlazaSurface", Vector3(0, 0.014, 0),
        Vector3(size.x, 0.022, size.y), base)
    for step in range(3):
        var z: float = -2.2 + float(step) * 2.2
        _mesh(plaza, "PavingBand_%d" % step, Vector3(0, 0.028, z),
            Vector3(size.x - 1.1, 0.012, 0.18), stone)
    for side in [-1, 1]:
        var x: float = float(side) * (size.x * 0.35)
        _mesh(plaza, "BenchSeat_%d" % side, Vector3(x, 0.53, 0.2),
            Vector3(1.45, 0.12, 0.48), timber)
        _mesh(plaza, "BenchBack_%d" % side, Vector3(x, 0.86, 0.43),
            Vector3(1.45, 0.72, 0.12), timber)
    match str(plot["theme"]):
        "garden":
            for side in [-1, 1]:
                _mesh(plaza, "RaisedPlanter_%d" % side,
                    Vector3(float(side) * 3.1, 0.30, -3.5),
                    Vector3(1.5, 0.56, 1.6), accent)
                _mesh(plaza, "PlanterGreen_%d" % side,
                    Vector3(float(side) * 3.1, 0.70, -3.5),
                    Vector3(1.2, 0.38, 1.3), _material(Color(0.18, 0.56, 0.28)))
        "heritage":
            _mesh(plaza, "HeritagePlinth", Vector3(0, 0.42, -2.7),
                Vector3(2.0, 0.76, 1.6), stone)
            _mesh(plaza, "HeritageMarker", Vector3(0, 1.43, -2.7),
                Vector3(0.75, 1.3, 0.75), accent)
        "community":
            _mesh(plaza, "CommunityNoticeboard", Vector3(0, 1.25, -3.4),
                Vector3(3.4, 1.75, 0.18), accent)
            _mesh(plaza, "NoticeboardPostLeft", Vector3(-1.2, 0.55, -3.4),
                Vector3(0.13, 1.1, 0.13), timber)
            _mesh(plaza, "NoticeboardPostRight", Vector3(1.2, 0.55, -3.4),
                Vector3(0.13, 1.1, 0.13), timber)
    _title(plaza, str(plot["title"]), Vector3(0, 2.0, 3.0))
