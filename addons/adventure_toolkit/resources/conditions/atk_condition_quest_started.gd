@tool
class_name ATKConditionQuestStarted
extends ATKCondition

## True when the quest has been started and is not completed.


@export var quest_id := ""


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if quest_id.is_empty():
		return fail("Quest-started condition '%s' needs quest_id." % get_debug_name())

	var quests := _resolve_quests(context)
	if quests == null or not quests.has_method("is_quest_started"):
		return fail("ATKQuests missing for quest-started condition '%s'." % get_debug_name())

	var started: bool = bool(quests.call("is_quest_started", quest_id))
	if started:
		return succeed(
			"Quest '%s' is started." % quest_id,
			{"quest_id": quest_id}
		)
	return fail("Quest '%s' is not started." % quest_id, {"quest_id": quest_id})


func _resolve_quests(context: Dictionary) -> Node:
	if context.get("quests") is Node:
		return context["quests"] as Node
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKQuests")
