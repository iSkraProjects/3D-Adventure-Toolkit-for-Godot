@tool
class_name ATKConditionQuestStage
extends ATKCondition

## Compares current quest stage from ATKQuests (or context override).


@export var quest_id := ""
@export var expected_stage := 0
@export var at_least_stage := false


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if quest_id.is_empty():
		return fail("Quest-stage condition '%s' needs quest_id." % get_debug_name())

	var current := _resolve_current_stage(context)
	var passed := false
	if at_least_stage:
		passed = current >= expected_stage
	else:
		passed = current == expected_stage

	if passed:
		return succeed(
			"Quest '%s' stage check passed (current=%d)." % [quest_id, current],
			{"quest_id": quest_id, "current_stage": current, "expected_stage": expected_stage, "at_least": at_least_stage}
		)

	var expectation := "stage>=%d" % expected_stage if at_least_stage else "stage==%d" % expected_stage
	return fail(
		"Quest '%s' stage check failed (current=%d, need %s)." % [quest_id, current, expectation],
		{"quest_id": quest_id, "current_stage": current, "expected_stage": expected_stage, "at_least": at_least_stage}
	)


func _resolve_current_stage(context: Dictionary) -> int:
	if context.has("quest_stage"):
		var qs = context["quest_stage"]
		if qs is Dictionary:
			return int((qs as Dictionary).get(quest_id, 0))
	if context.has("quest_stages") and context["quest_stages"] is Dictionary:
		return int((context["quest_stages"] as Dictionary).get(quest_id, 0))

	var quests := _resolve_quests(context)
	if quests != null and quests.has_method("get_quest_stage"):
		return int(quests.call("get_quest_stage", quest_id))

	return 0


func _resolve_quests(context: Dictionary) -> Node:
	if context.get("quests") is Node:
		return context["quests"] as Node
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKQuests")
