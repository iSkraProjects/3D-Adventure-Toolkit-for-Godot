@tool
class_name ATKConditionSceneState
extends ATKCondition


@export var scene_id := ""
@export var state_key := ""
@export var expected_value: Variant
@export var require_exact_match := true


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if state_key.is_empty():
		return fail("Scene-state condition '%s' is missing state_key." % get_debug_name())

	var state := _resolve_state_manager(context)
	if state == null:
		return fail("Scene-state condition '%s' could not find ATKState." % get_debug_name())

	var resolved_scene_id := _resolve_scene_id(context)
	if resolved_scene_id.is_empty():
		return fail("Scene-state condition '%s' has no scene_id to evaluate." % get_debug_name())

	var actual: Variant = state.get_scene(resolved_scene_id, state_key, null)
	var passed: bool = false
	if require_exact_match:
		passed = actual == expected_value
	else:
		passed = state.has_scene(resolved_scene_id, state_key)

	if passed:
		return succeed(
			"Scene state '%s/%s' passed." % [resolved_scene_id, state_key],
			{"scene_id": resolved_scene_id, "state_key": state_key, "actual": actual, "expected": expected_value}
		)

	return fail(
		"Scene state '%s/%s' failed." % [resolved_scene_id, state_key],
		{"scene_id": resolved_scene_id, "state_key": state_key, "actual": actual, "expected": expected_value}
	)


func _resolve_scene_id(context: Dictionary) -> String:
	if not scene_id.is_empty():
		return scene_id
	if context.has("scene_id"):
		return str(context.get("scene_id", ""))

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return ""
	var scenes := tree.root.get_node_or_null("ATKScenes")
	if scenes == null:
		return ""
	return str(scenes.current_scene_id)


func _resolve_state_manager(context: Dictionary) -> Node:
	if context.has("state") and context["state"] is Node:
		return context["state"] as Node

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")
