extends Node

## Registers a small demo quest and optional welcome journal line when `scene_test_adventure` loads.


@export var quest_definition: ATKQuestDefinition
@export var welcome_journal_title := "Welcome"
@export_multiline var welcome_journal_body := "This note was added when the demo scene started. Objectives for the mini-quest appear above."
@export var welcome_journal_entry_id := "demo_journal_welcome"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var quests := get_node_or_null("/root/ATKQuests")
	if quests != null and quest_definition != null:
		quests.register_quest_definition(quest_definition)
		var qid := quest_definition.quest_id.strip_edges()
		if not qid.is_empty():
			quests.start_quest(qid)

	var state := get_node_or_null("/root/ATKState")
	var journal := get_node_or_null("/root/ATKJournal")
	if journal == null or state == null:
		return
	if bool(state.get_global("atk_demo_journal_welcome_added", false)):
		return
	journal.add_journal_entry(welcome_journal_title, welcome_journal_body, welcome_journal_entry_id)
	state.set_global("atk_demo_journal_welcome_added", true)
