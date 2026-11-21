extends SceneTree
## MAP-002B: colored regions are sourced from real known street objects
## and must not change the source-of-truth road graph or mission routes.
const Districts = preload("res://scripts/ui/civic_map_districts.gd")
const Map = preload("res://scripts/ui/civic_city_map.gd")
const Network = preload("res://scripts/world/city_network_definition.gd")
const LivingZones = preload("res://scripts/world/living_city_zones.gd")
const Organic = preload("res://scripts/world/organic_road_geometry.gd")
var failures: int = 0

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("MAP-002B: " + message)

## Existing market/collector roads retain stable lane IDs 100..179.
## Independent map PR may be reviewed before or after WORLD-002C2.
## Only the two explicitly reserved appended road IDs are supported.
func _stable_inventory(roads: Array[Dictionary]) -> bool:
    if roads.size() != 40 and roads.size() != 42:
        return false
    for i in range(40):
        if int(roads[i].get("lane_forward", -1)) != 100 + i * 2 or (
                int(roads[i].get("lane_reverse", -1)) != 101 + i * 2):
            return false
    if roads.size() == 42:
        for i in range(2):
            var road: Dictionary = roads[40 + i]
            if not bool(road.get("world_002_connector", false)) or (
                    int(road.get("lane_forward", -1)) != 1000 + i * 2) or (
                    int(road.get("lane_reverse", -1)) != 1001 + i * 2):
                return false
    return true

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(Districts.validate(), "district definitions cross real streets or mismatch destinations")
    _check(Districts.REGIONS.size() == 6, "expected six grounded neighborhood areas")
    _check(Districts.SERVICES.size() == 2, "expected existing bus stop and parking")
    _check(_stable_inventory(Network.roads()), "legacy roads or new appended street IDs changed")
    var organic_found: bool = false
    for road in Network.roads():
        if bool(road.get("organic_pilot", false)):
            _check((road["centerline"] as PackedVector3Array) == Organic.centerline(),
                "physical S-bend changed")
            organic_found = true
    _check(organic_found, "organic pilot road missing")
    var ids: Dictionary = {}
    for region in Districts.regions():
        var id: String = str(region["id"])
        _check(not ids.has(id), "duplicate region ID")
        ids[id] = true
        var poly: PackedVector3Array = Districts.polygon(region)
        _check(poly.size() == 8, "district must have eight corner/bevel points: " + id)
        for world in poly:
            var rect: Rect2 = region["bounds"]
            _check(world.is_finite() and rect.grow(0.001).has_point(Vector2(world.x, world.z)),
                "district polygon goes outside known land block: " + id)
        var region_at_center: Dictionary = Districts.closest_region(region["center"])
        _check(str(region_at_center.get("id", "")) == id,
            "region lookup not stable at mapped center: " + id)
    for zone in LivingZones.LOCATIONS:
        _check(ids.has(zone["id"]), "living zone missing map district")
        var found: Dictionary = Districts.closest_region(zone["position"])
        _check(str(found.get("id", "")) == str(zone["id"]),
            "living zone not inside own district")
    _check(Districts.closest_region(Vector3.ZERO).is_empty(),
        "central junction incorrectly painted as a district")
    var display := Rect2(0, 0, 320, 320)
    var project := func(at: Vector3) -> Vector2:
        return Map.full_view_project(at, display, Vector2.ZERO, 1.0)
    for region in Districts.regions():
        var projected: PackedVector2Array = Districts.project_polygon(region, project)
        _check(projected.size() == 8 and Districts.visible(projected, display),
            "full map district projection invisible")
        var hidden: PackedVector2Array = Districts.project_polygon(
            region, func(at: Vector3) -> Vector2:
                return project.call(at) + Vector2(2000, 2000))
        _check(not Districts.visible(hidden, display),
            "off-screen district not culled")
    var map_ui: CivicCityMap = Map.new() as CivicCityMap
    root.add_child(map_ui)
    await process_frame
    _check(map_ui.small_frame.visible, "minimap lost startup visibility")
    var before: int = map_ui.selected_location
    map_ui.update_position(Vector3(13, 0, -33), Vector3.FORWARD, {})
    map_ui.set_expanded(true)
    _check(map_ui.large_frame.visible and not map_ui.small_frame.visible,
        "opening district map broke modal state")
    map_ui.zoom_at(1.25)
    _check(map_ui.map_zoom > 1.0 and map_ui.selected_location == before,
        "district layer interfered with pan/zoom or navigation selection")
    map_ui.set_expanded(false)
    _check(map_ui.small_frame.visible, "minimap did not return")
    map_ui.queue_free()
    if failures == 0:
        print("CIVIC_CHAOS_MAP_002B_DISTRICTS_PASS")
    else:
        print("CIVIC_CHAOS_MAP_002B_DISTRICTS_FAIL %d" % failures)
    quit(0 if failures == 0 else 1)
