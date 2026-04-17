@tool
class_name ATKConditionGlobalState
extends ATKCondition


@export var state_key := ""
@export var expected_value: Variant
@export var require_exact_match := true


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if state_key.is_empty():
		return fail("Global-state condition '%s' is missing state_key." % get_debug_name())

	var state := _resolve_state_manager(context)
	if state == null:
		return fail("Global-state condition '%s' could not find ATKState." % get_debug_name())

	var actual: Variant = state.get_global(state_key, null)
	var passed: bool = false
	if require_exact_match:
		passed = actual == expected_value
	else:
		passed = state.has_global(state_key)

	if passed:
		return succeed(
			"Global state '%s' passed." % state_key,
			{"state_key": state_key, "actual": actual, "expected": expected_value}
		)

	return fail(
		"Global state '%s' failed." % state_key,
		{"state_key": state_key, "actual": actual, "expected": expected_value}
	)


func _resolve_state_manager(context: Dictionary) -> Node:
	if context.has("state") and context["state"] is Node:
		return context["state"] as Node

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")
