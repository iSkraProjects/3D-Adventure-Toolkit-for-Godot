@tool
class_name ATKActionStepSetQuestStage
extends ATKActionStep

@export var quest_id := ""
@export var stage := 0


func run(_context: ATKActionContext) -> void:
	if quest_id.is_empty():
		ATKLog.warn("Set-quest-stage step '%s' has empty quest_id." % _debug_name(), "ATKAction")
		return
	var quests := _get_quests_autoload()
	if quests == null or not quests.has_method("set_quest_stage"):
		ATKLog.warn("ATKQuests missing for set-quest-stage step '%s'." % _debug_name(), "ATKAction")
		return
	quests.call("set_quest_stage", quest_id, stage)
	ATKLog.debug("Quest '%s' stage -> %d." % [quest_id, stage], "ATKAction")


func _get_quests_autoload() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKQuests")
