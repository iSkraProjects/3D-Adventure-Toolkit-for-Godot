@tool
class_name ATKQuestDefinition
extends Resource

## Authored quest metadata (Phase 11). Runtime progression lives in `ATKQuests`.

@export var quest_id := ""
@export var display_name := ""
@export_multiline var description := ""
## Optional label per stage index (0 = first stage after `start_quest`).
@export var objective_stage_labels: PackedStringArray = []
@export var is_hidden := false
## When current stage equals this, `complete_quest` is the usual next step (not enforced at runtime).
@export var final_stage_index := 0
