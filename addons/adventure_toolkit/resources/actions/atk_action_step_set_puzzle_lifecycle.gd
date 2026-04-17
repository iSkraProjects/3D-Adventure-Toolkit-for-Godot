@tool
class_name ATKActionStepSetPuzzleLifecycle
extends ATKActionStep

## Writes puzzle `lifecycle` on `ATKState` object scope (same contract as ATKPuzzleController).


const LIFECYCLE_KEY := "lifecycle"


@export var puzzle_id := ""
@export var lifecycle := "unsolved"


func run(_context: ATKActionContext) -> void:
	if puzzle_id.is_empty():
		ATKLog.warn("Set-puzzle-lifecycle step '%s' has empty puzzle_id." % _debug_name(), "ATKAction")
		return
	var lc := lifecycle.strip_edges()
	if not _is_valid_lifecycle(lc):
		ATKLog.warn("Set-puzzle-lifecycle step '%s' has invalid lifecycle '%s'." % [_debug_name(), lc], "ATKAction")
		return
	var state := _get_state()
	if state == null:
		ATKLog.warn("ATKState missing for set-puzzle-lifecycle step '%s'." % _debug_name(), "ATKAction")
		return
	state.set_object(puzzle_id, LIFECYCLE_KEY, lc)
	ATKLog.debug("Puzzle '%s' lifecycle -> %s." % [puzzle_id, lc], "ATKAction")


func _is_valid_lifecycle(value: String) -> bool:
	return value == "unsolved" or value == "solved" or value == "failed"


func _get_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")
