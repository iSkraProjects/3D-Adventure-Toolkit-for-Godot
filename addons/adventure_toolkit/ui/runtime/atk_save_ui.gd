extends CanvasLayer

## Save / load panel (Phase 14 / T14.3). Parented under [ATKSave] so it survives scene changes.
## Saving into a slot that already has data asks for overwrite confirmation first.
## **Delete** removes the file for the selected slot after a confirmation dialog ([signal ATKSave.delete_finished]).
## Overwrite / delete confirmations can be dismissed by clicking the dimmed backdrop (same as Cancel).
## Keyboard toggle uses **Project Settings → Input Map** [member keyboard_action] (default [code]atk_toggle_save_menu[/code]).
## If the action has no bindings yet, [ATKUiInputActions] assigns [kbd]G[/kbd] once. Set [member allow_keyboard_toggle]
## to [code]false[/code] for mouse-only games and open this panel from buttons (e.g. pause menu).


const _DEFAULT_TOGGLE_KEY := KEY_G

@export var allow_keyboard_toggle := true
@export var keyboard_action := "atk_toggle_save_menu"
@export var start_visible := false
@export var slot_ids: PackedStringArray = PackedStringArray(["slot_1", "slot_2", "slot_3"])

@onready var _root: Control = $Root
@onready var _item_list: ItemList = $Root/Panel/Margin/VBox/SlotList
@onready var _status: Label = $Root/Panel/Margin/VBox/Status
@onready var _btn_save: Button = $Root/Panel/Margin/VBox/Buttons/SaveButton
@onready var _btn_load: Button = $Root/Panel/Margin/VBox/Buttons/LoadButton
@onready var _btn_delete: Button = $Root/Panel/Margin/VBox/Buttons/DeleteButton
@onready var _btn_refresh: Button = $Root/Panel/Margin/VBox/Buttons/RefreshButton
@onready var _btn_close: Button = $Root/Panel/Margin/VBox/Buttons/CloseButton
@onready var _modal_backdrop: ColorRect = $ModalBackdrop
@onready var _overwrite_dialog: ConfirmationDialog = $OverwriteSaveDialog
@onready var _delete_dialog: ConfirmationDialog = $DeleteSaveDialog

var _overwrite_slot_pending := ""
var _delete_slot_pending := ""
var _status_success_color := Color(0.42, 0.92, 0.55)
var _status_flash_generation := 0

## When opened from another [CanvasLayer] (e.g. main menu), we raise this layer and lower the partner until close.
var _stack_partner: CanvasLayer = null
var _stack_partner_layer_backup := -1
var _default_layer := 29


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_default_layer = layer
	visible = start_visible
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE if not start_visible else Control.MOUSE_FILTER_STOP

	var save := get_node_or_null("/root/ATKSave")
	if save == null:
		push_warning("ATKSaveUI: ATKSave autoload missing.")
		return

	if save.has_signal("save_finished"):
		save.save_finished.connect(_on_save_finished)
	if save.has_signal("load_finished"):
		save.load_finished.connect(_on_load_finished)
	if save.has_signal("delete_finished"):
		save.delete_finished.connect(_on_delete_finished)

	_btn_save.pressed.connect(_on_save_pressed)
	_btn_load.pressed.connect(_on_load_pressed)
	_btn_delete.pressed.connect(_on_delete_pressed)
	_btn_refresh.pressed.connect(_on_refresh_pressed)
	_btn_close.pressed.connect(_on_close_pressed)
	_overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
	_overwrite_dialog.canceled.connect(_on_overwrite_canceled)
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	_delete_dialog.canceled.connect(_on_delete_canceled)
	_overwrite_dialog.visibility_changed.connect(_sync_modal_backdrop)
	_delete_dialog.visibility_changed.connect(_sync_modal_backdrop)
	_modal_backdrop.gui_input.connect(_on_modal_backdrop_gui_input)

	if not keyboard_action.strip_edges().is_empty():
		ATKUiInputActions.ensure_action_with_default_key(keyboard_action, _DEFAULT_TOGGLE_KEY)

	_refresh_slot_list()


## Called by the pause overlay after opening this panel while the tree is paused.
func refresh_panel() -> void:
	_refresh_slot_list()


## Show this panel above [param partner] (typically the main menu [CanvasLayer]). Restores [member CanvasLayer.layer]
## on both nodes when the panel closes or after a successful load.
func open_above_canvas(partner: CanvasLayer) -> void:
	if partner == null:
		return
	_restore_canvas_stack_if_any()
	_stack_partner = partner
	_stack_partner_layer_backup = partner.layer
	partner.layer = 1
	layer = maxi(_default_layer, _stack_partner_layer_backup + 1)
	visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	refresh_panel()


func _restore_canvas_stack_if_any() -> void:
	if _stack_partner_layer_backup < 0:
		return
	if _stack_partner != null and is_instance_valid(_stack_partner):
		_stack_partner.layer = _stack_partner_layer_backup
	_stack_partner = null
	_stack_partner_layer_backup = -1
	layer = _default_layer


func _unhandled_input(event: InputEvent) -> void:
	if not allow_keyboard_toggle:
		return
	if not _keyboard_shortcuts_allowed():
		return
	if keyboard_action.strip_edges().is_empty():
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not event.is_action_pressed(StringName(keyboard_action)):
		return
	visible = not visible
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	if visible:
		refresh_panel()
	else:
		_restore_canvas_stack_if_any()
		var pause_toggle := get_parent().get_node_or_null("DefaultPauseOverlay")
		if pause_toggle != null and pause_toggle.has_method("notify_save_ui_closed"):
			pause_toggle.notify_save_ui_closed()
	get_viewport().set_input_as_handled()


func _sync_modal_backdrop() -> void:
	_modal_backdrop.visible = _overwrite_dialog.visible or _delete_dialog.visible


func _on_modal_backdrop_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _overwrite_dialog.visible:
		_overwrite_dialog.hide()
		_on_overwrite_canceled()
	elif _delete_dialog.visible:
		_delete_dialog.hide()
		_on_delete_canceled()
	get_viewport().set_input_as_handled()


func _selected_slot_id() -> String:
	var idxs := _item_list.get_selected_items()
	if idxs.is_empty():
		return ""
	return str(_item_list.get_item_metadata(idxs[0]))


func _refresh_slot_list() -> void:
	_item_list.clear()
	for slot_id in slot_ids:
		if slot_id.strip_edges().is_empty():
			continue
		var label := _format_slot_row(slot_id)
		var i := _item_list.add_item(label)
		_item_list.set_item_metadata(i, slot_id)
	if _item_list.item_count > 0:
		_item_list.select(0)


func _format_slot_row(slot_id: String) -> String:
	if not ATKSave.has_slot(slot_id):
		return "%s — (empty)" % slot_id
	var meta: Dictionary = ATKSave.get_slot_metadata(slot_id)
	var ts := str(meta.get("display_timestamp", ""))
	if ts.is_empty():
		return "%s — (saved)" % slot_id
	return "%s — %s" % [slot_id, ts]


func _on_save_pressed() -> void:
	var sid := _selected_slot_id()
	if sid.is_empty():
		_status.text = "Select a slot first."
		return
	if ATKSave.has_slot(sid):
		_overwrite_slot_pending = sid
		_overwrite_dialog.dialog_text = (
			"This slot already contains a saved game.\nOverwrite \"%s\"? This cannot be undone." % sid
		)
		_overwrite_dialog.popup_centered()
		return
	_perform_save(sid)


func _perform_save(slot_id: String) -> void:
	_status.text = "Saving…"
	ATKSave.save_slot(slot_id)


func _on_overwrite_confirmed() -> void:
	var sid := _overwrite_slot_pending
	_overwrite_slot_pending = ""
	if sid.is_empty():
		return
	_perform_save(sid)


func _on_overwrite_canceled() -> void:
	_overwrite_slot_pending = ""


func _on_delete_pressed() -> void:
	var sid := _selected_slot_id()
	if sid.is_empty():
		_status.text = "Select a slot first."
		return
	if not ATKSave.has_slot(sid):
		_status.text = "That slot is already empty."
		return
	_delete_slot_pending = sid
	_delete_dialog.dialog_text = (
		"Delete the saved game in \"%s\"?\n\nThis will free the slot permanently. This cannot be undone." % sid
	)
	_delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	var sid := _delete_slot_pending
	_delete_slot_pending = ""
	if sid.is_empty():
		return
	ATKSave.delete_slot(sid)


func _on_delete_canceled() -> void:
	_delete_slot_pending = ""


func _on_delete_finished(_slot_id: String, success: bool, message: String) -> void:
	if not visible:
		return
	if not success:
		_status.text = message
		_refresh_slot_list()
		return
	_refresh_slot_list()
	_show_save_success_feedback(message)


func _on_load_pressed() -> void:
	var sid := _selected_slot_id()
	if sid.is_empty():
		_status.text = "Select a slot first."
		return
	if not ATKSave.has_slot(sid):
		_status.text = "That slot is empty."
		return
	_status.text = "Loading…"
	var ok: bool = await ATKSave.load_slot_and_restore(sid)
	if ok:
		_close_after_successful_load()
	else:
		_status.text = "Load failed."
		refresh_panel()


func _on_refresh_pressed() -> void:
	refresh_panel()
	_status.text = "Slot list refreshed."


func _on_close_pressed() -> void:
	visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_canvas_stack_if_any()
	var pause := get_parent().get_node_or_null("DefaultPauseOverlay")
	if pause != null and pause.has_method("notify_save_ui_closed"):
		pause.notify_save_ui_closed()


func _close_after_successful_load() -> void:
	visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_canvas_stack_if_any()
	var pause := get_parent().get_node_or_null("DefaultPauseOverlay")
	if pause != null and pause.has_method("dismiss_after_successful_load"):
		pause.dismiss_after_successful_load()
	_show_loaded_toast()


func _show_loaded_toast() -> void:
	var bus := get_node_or_null("/root/ATKInteractionFeedback")
	if bus != null and bus.has_method("show_message"):
		bus.show_message("Game loaded successfully. You can continue playing from here.", "Loaded")


func _show_save_success_feedback(message: String) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", _status_success_color)
	_status_flash_generation += 1
	var gen := _status_flash_generation
	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(self) or gen != _status_flash_generation:
		return
	_status.remove_theme_color_override("font_color")


func _on_save_finished(_slot_id: String, success: bool, message: String) -> void:
	if not visible:
		return
	if not success:
		_status.text = message
		return
	_refresh_slot_list()
	_show_save_success_feedback(message)


func _on_load_finished(_slot_id: String, success: bool, message: String) -> void:
	if not visible:
		return
	_status.text = message
	if success:
		_refresh_slot_list()


func _keyboard_shortcuts_allowed() -> bool:
	var settings := get_node_or_null("/root/ATKSettings")
	if settings == null or not settings.has_method("is_keyboard_shortcuts_enabled"):
		return true
	return bool(settings.call("is_keyboard_shortcuts_enabled"))
