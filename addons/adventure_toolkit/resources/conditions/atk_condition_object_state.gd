@tool
class_name ATKConditionObjectState
extends ATKCondition


@export var object_id := ""
@export var state_key := ""
@export var expected_value: Variant
@export var require_exact_match := true


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if state_key.is_empty():
		return fail("Object-state condition '%s' is missing state_key." % get_debug_name())

	var resolved_object_id := _resolve_object_id(context)
	if resolved_object_id.is_empty():
		return fail("Object-state condition '%s' has no object_id to evaluate." % get_debug_name())

	var state := _resolve_state_manager(context)
	if state == null:
		return fail("Object-state condition '%s' could not find ATKState." % get_debug_name())

	var actual: Variant = state.get_object(resolved_object_id, state_key, null)
	var passed: bool = false
	if require_exact_match:
		passed = actual == expected_value
	else:
		passed = state.has_object(resolved_object_id, state_key)

	if passed:
		return succeed(
			"Object state '%s/%s' passed." % [resolved_object_id, state_key],
			{"object_id": resolved_object_id, "state_key": state_key, "actual": actual, "expected": expected_value}
		)

	return fail(
		"Object state '%s/%s' failed." % [resolved_object_id, state_key],
		{"object_id": resolved_object_id, "state_key": state_key, "actual": actual, "expected": expected_value}
	)


func _resolve_object_id(context: Dictionary) -> String:
	if not object_id.is_empty():
		return object_id
	if context.has("object_id"):
		return str(context.get("object_id", ""))
	return ""


func _resolve_state_manager(context: Dictionary) -> Node:
	if context.has("state") and context["state"] is Node:
		return context["state"] as Node

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")
