@tool
class_name ATKConditionRepeatInteraction
extends ATKCondition

## Passes when `interaction_count` in ATKState object scope is greater than zero.
## Evaluate before increment for "second click onward"; after first increment, count is 1.


@export var object_id := ""


func _evaluate_internal(context: Dictionary) -> Dictionary:
	var oid := _resolve_object_id(context)
	if oid.is_empty():
		return fail("Repeat-interaction condition '%s' needs object_id." % get_debug_name())

	var state := _resolve_state(context)
	if state == null:
		return fail("Repeat-interaction condition '%s' could not find ATKState." % get_debug_name())

	var count := int(state.get_object(oid, "interaction_count", 0))
	if count > 0:
		return succeed(
			"Object '%s' has prior interactions (count=%d)." % [oid, count],
			{"object_id": oid, "interaction_count": count}
		)

	return fail(
		"Object '%s' has no prior interactions (count=0)." % oid,
		{"object_id": oid, "interaction_count": count}
	)


func _resolve_object_id(context: Dictionary) -> String:
	if not object_id.is_empty():
		return object_id
	return str(context.get("object_id", ""))


func _resolve_state(context: Dictionary) -> Node:
	if context.get("state") is Node:
		return context["state"] as Node
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")
