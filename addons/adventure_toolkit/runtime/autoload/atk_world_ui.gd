extends Node

## Central place for "world" UI lock state (dialogue, inventory panel, interaction toast, etc.).
## [ATKPlayerController] and [ATKInteractionHover] use this so behavior stays consistent.


func is_world_interaction_locked() -> bool:
	var dlg := get_node_or_null("/root/ATKDialogue")
	if dlg != null and dlg.has_method("is_active") and bool(dlg.call("is_active")):
		return true
	var inv_ui := get_node_or_null("/root/ATKInventory/DefaultInventoryUI")
	if inv_ui != null and inv_ui.has_method("is_inventory_panel_open"):
		if bool(inv_ui.call("is_inventory_panel_open")):
			return true
	var journal_ui := get_node_or_null("/root/ATKJournal/DefaultObjectiveJournalUI")
	if journal_ui != null and journal_ui.has_method("is_journal_panel_open"):
		if bool(journal_ui.call("is_journal_panel_open")):
			return true
	var hint_ui := get_node_or_null("/root/ATKHints/DefaultHintUI")
	if hint_ui != null and hint_ui.has_method("is_hint_panel_open"):
		if bool(hint_ui.call("is_hint_panel_open")):
			return true
	var feedback := get_node_or_null("/root/ATKInteractionFeedback")
	if feedback != null and feedback.has_method("is_interaction_message_open"):
		if bool(feedback.call("is_interaction_message_open")):
			return true
	return false
