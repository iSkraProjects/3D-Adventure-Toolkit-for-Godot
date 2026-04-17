class_name ATKNPC
extends ATKAdventureObject


## Optional stable id for tools / future lookups (dialogue asset naming, etc.).
@export var dialogue_id := ""
@export var dialogue: ATKDialogueDefinition
@export var dialogue_camera: Camera3D
@export var dialogue_camera_priority := 60

## Optional no-code item handover flow for designer-authored NPC trades.
@export_group("Item Handover")
@export var handover_enabled := false
@export var handover_required_item_id := ""
@export var handover_require_selected_item := true
@export var handover_consume_item := true
@export var handover_only_once := true
@export var handover_success_line := ""
@export var handover_missing_item_line := "Maybe they want something you're carrying."
@export var handover_success_global_key := ""
@export var handover_success_global_value: Variant = true
@export_group("")


func interact_default(actor: Node) -> void:
	if not can_interact():
		return
	if _resolve_active_verb(actor) == "inspect":
		await super.interact_default(actor)
		return
	if handover_enabled and await _try_item_handover_flow():
		_increment_interaction_count()
		return
	if dialogue != null:
		var dlg := get_node_or_null("/root/ATKDialogue")
		if dlg != null and dlg.has_method("start_dialogue"):
			await dlg.start_dialogue(
				dialogue,
				actor,
				self,
				false,
				dialogue_camera,
				dialogue_camera_priority
			)
		_increment_interaction_count()
		return
	await super.interact_default(actor)


func _try_item_handover_flow() -> bool:
	var item_id := handover_required_item_id.strip_edges()
	if item_id.is_empty():
		return false
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory == null:
		return false

	var already_done := false
	if handover_only_once and not object_id.is_empty():
		var state := get_node_or_null("/root/ATKState")
		if state != null:
			already_done = bool(state.get_object(object_id, "handover_complete", false))
	if already_done:
		return false

	var selected := ""
	if inventory.has_method("get_selected_item"):
		selected = str(inventory.call("get_selected_item"))
	var has_required := false
	if inventory.has_method("has_item"):
		has_required = bool(inventory.call("has_item", item_id, 1))
	if handover_require_selected_item and selected != item_id:
		_show_line(handover_missing_item_line)
		return true
	if not has_required:
		_show_line(handover_missing_item_line)
		return true

	if handover_consume_item and inventory.has_method("remove_item"):
		inventory.call("remove_item", item_id, 1)

	var gk := handover_success_global_key.strip_edges()
	if not gk.is_empty():
		var state2 := get_node_or_null("/root/ATKState")
		if state2 != null and state2.has_method("set_global"):
			state2.call("set_global", gk, handover_success_global_value)

	if handover_only_once and not object_id.is_empty():
		var state3 := get_node_or_null("/root/ATKState")
		if state3 != null:
			state3.set_object(object_id, "handover_complete", true)

	_show_line(handover_success_line)
	return true


func _show_line(line: String) -> void:
	var text := line.strip_edges()
	if text.is_empty():
		return
	var bus := get_node_or_null("/root/ATKInteractionFeedback")
	if bus != null and bus.has_method("show_message"):
		var title := display_name if not display_name.is_empty() else name
		bus.show_message(text, title, object_id)
