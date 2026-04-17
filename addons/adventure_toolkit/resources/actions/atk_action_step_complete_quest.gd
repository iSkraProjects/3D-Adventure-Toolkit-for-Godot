@tool
class_name ATKActionStepCompleteQuest
extends ATKActionStep

@export var quest_id := ""


func run(_context: ATKActionContext) -> void:
	if quest_id.is_empty():
		ATKLog.warn("Complete-quest step '%s' has empty quest_id." % _debug_name(), "ATKAction")
		return
	var quests := _get_quests()
	if quests == null or not quests.has_method("complete_quest"):
		ATKLog.warn("ATKQuests missing for complete-quest step '%s'." % _debug_name(), "ATKAction")
		return
	quests.call("complete_quest", quest_id)
	ATKLog.debug("Quest '%s' completed." % quest_id, "ATKAction")


func _get_quests() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKQuests")
