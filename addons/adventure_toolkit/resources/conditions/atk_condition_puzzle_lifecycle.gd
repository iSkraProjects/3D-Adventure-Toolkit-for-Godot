@tool
class_name ATKConditionPuzzleLifecycle
extends ATKCondition

## Matches `ATKState` object scope `lifecycle` for `puzzle_id` (same key as ATKPuzzleController).


const LIFECYCLE_KEY := "lifecycle"


@export var puzzle_id := ""
@export var expected_lifecycle := "unsolved"


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if puzzle_id.is_empty():
		return fail("Puzzle-lifecycle condition '%s' needs puzzle_id." % get_debug_name())

	var current := _read_lifecycle(context)
	if current == expected_lifecycle:
		return succeed(
			"Puzzle '%s' is '%s'." % [puzzle_id, current],
			{"puzzle_id": puzzle_id, "lifecycle": current}
		)
	return fail(
		"Puzzle '%s' is '%s' (need '%s')." % [puzzle_id, current, expected_lifecycle],
		{"puzzle_id": puzzle_id, "lifecycle": current, "expected": expected_lifecycle}
	)


func _read_lifecycle(context: Dictionary) -> String:
	if context.has("puzzle_lifecycle") and context["puzzle_lifecycle"] is Dictionary:
		return str((context["puzzle_lifecycle"] as Dictionary).get(puzzle_id, "unsolved"))

	var state := _resolve_state(context)
	if state == null:
		return "unsolved"
	return str(state.get_object(puzzle_id, LIFECYCLE_KEY, "unsolved"))


func _resolve_state(context: Dictionary) -> Node:
	if context.get("state") is Node:
		return context["state"] as Node
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")
