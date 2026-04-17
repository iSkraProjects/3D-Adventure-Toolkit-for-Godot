@tool
class_name ATKPuzzleDefinition
extends Resource

## Authored puzzle metadata and optional outcome sequences (Phase 12).


@export var puzzle_id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var on_success_actions: ATKActionSequence
@export var on_failure_actions: ATKActionSequence
@export var on_reset_actions: ATKActionSequence
## When set, overrides scene-level hints while this puzzle is unsolved (Phase 16).
@export var puzzle_hint_bank: ATKHintBank
