class_name CivicLivingCityExploration
extends Node3D
## GAME-025-03: lightweight exploration scenery and visit feedback.
## Never owns a collision body, creates incidents or grants civic rewards.
signal zone_discovered(zone_id: String, title: String)

const Zones = preload("res://scripts/world/living_city_zones.gd")
const POLL_INTERVAL: float = 0.30

var player: Node3D
var discoveries: Dictionary = {}
var _elapsed: float = 0.0

func configure(actor: Node3D) -> bool:
    if actor == null or not is_inside_tree() or player != null or not Zones.valid_layout():
        return false
    player = actor
    _build_landmarks()
    return true

func _process(delta: float) -> void:
    if player == null or delta <= 0.0:
        return
    _elapsed += minf(delta, 0.25)
    if _elapsed < POLL_INTERVAL:
        return
    _elapsed = 0.0
    scan_position(player.global_position)

func scan_position(at: Vector3) -> void:
    for zone_id in Zones.nearby(at):
        if discoveries.has(zone_id):
            continue
        var zone: Dictionary = Zones.by_id(zone_id)
        if zone.is_empty():
            continue
        discoveries[zone_id] = true
        zone_discovered.emit(zone_id, str(zone["title"]))

func visit_state() -> Dictionary:
    var names: Array[String] = []
    for zone in Zones.all():
        if discoveries.has(str(zone["id"])):
            names.append(str(zone["title"]))
    return {"visited": names, "count": names.size(), "total": Zones.LOCATIONS.size()}

func _build_landmarks() -> void:
    for zone in Zones.all():
        var marker := Node3D.new()
        marker.name = "Zone_" + str(zone["id"])
        marker.position = zone["position"]
        add_child(marker)
        var color: Color = zone["color"]
        _box(marker, "FootpathPlaque", Vector3(0, 0.045, 0),
            Vector3(1.25, 0.08, 0.95), color.darkened(0.40))
        _box(marker, "WayfindingPost", Vector3(0, 1.05, 0),
            Vector3(0.12, 2.1, 0.12), Color(0.22, 0.27, 0.33))
        _box(marker, "ColoredHeader", Vector3(0, 1.93, 0),
            Vector3(1.35, 0.42, 0.14), color)
        var nameplate := Label3D.new()
        nameplate.name = "ZoneName"
        nameplate.text = str(zone["title"]).to_upper()
        nameplate.position = Vector3(0, 2.32, 0)
        nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        nameplate.no_depth_test = false
        nameplate.font_size = 34
        nameplate.pixel_size = 0.004
        nameplate.modulate = Color(1, 1, 1, 0.95)
        marker.add_child(nameplate)

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3,
        color: Color) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.position = at
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var paint := StandardMaterial3D.new()
    paint.albedo_color = color
    paint.roughness = 0.95
    mesh.material_override = paint
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)
