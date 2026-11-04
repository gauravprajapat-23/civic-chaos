class_name SceneRegistry
extends RefCounted
## Centralized scene paths; avoids scattered string literals.

const MAIN: String = "res://scenes/core/main.tscn"
const MENU: String = "res://scenes/core/menu.tscn"
const PLAYER: String = "res://scenes/player/player_root.tscn"
const WORLD: String = "res://scenes/world/world_root.tscn"
const TRAFFIC: String = "res://scenes/traffic/traffic_root.tscn"
const NPC: String = "res://scenes/npcs/npc_root.tscn"
const MISSIONS: String = "res://scenes/missions/mission_root.tscn"
const UI: String = "res://scenes/ui/ui_root.tscn"

static func all_scene_paths() -> PackedStringArray:
    return PackedStringArray([MAIN, MENU, PLAYER, WORLD, TRAFFIC, NPC, MISSIONS, UI])
