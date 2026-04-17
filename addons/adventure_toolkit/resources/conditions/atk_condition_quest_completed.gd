@tool
class_name ATKConditionQuestCompleted
extends ATKCondition


@export var quest_id := ""


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if quest_id.is_empty():
		return fail("Quest-completed condition '%s' needs quest_id." % get_debug_name())

	var quests := _resolve_quests(context)
	if quests == null or not quests.has_method("is_quest_completed"):
		return fail("ATKQuests missing for quest-completed condition '%s'." % get_debug_name())

	var done: bool = bool(quests.call("is_quest_completed", quest_id))
	if done:
		return succeed("Quest '%s' is completed." % quest_id, {"quest_id": quest_id})
	return fail("Quest '%s' is not completed." % quest_id, {"quest_id": quest_id})


func _resolve_quests(context: Dictionary) -> Node:
	if context.get("quests") is Node:
		return context["quests"] as Node
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKQuests")
