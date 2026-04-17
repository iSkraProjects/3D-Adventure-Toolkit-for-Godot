@tool
class_name ATKEpisodeDefinition
extends Resource

## Phase 23.1: episode metadata + carryover conventions.

@export var episode_id := ""
@export var episode_label := ""
@export var start_scene_id := ""
@export var start_spawn_id := ""
@export var prior_episode_id := ""
@export var recap_lines: PackedStringArray = []
@export var carryover_global_keys: PackedStringArray = []
@export var carryover_inventory_item_ids: PackedStringArray = []
