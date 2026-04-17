extends CanvasLayer

## Default hint UI: requests the next layered hint from [ATKHints] and shows a modal panel.


const _DEFAULT_TOGGLE_KEY := KEY_H

@export var allow_keyboard_hint := true
@export var keyboard_action := "atk_request_hint"

@onready var _root: Control = $Root
@onready var _open_btn: TextureButton = $Root/OpenButton
@onready var _panel: PanelContainer = $Root/Panel
@onready var _title: Label = $Root/Panel/Margin/VBox/Title
@onready var _body: RichTextLabel = $Root/Panel/Margin/VBox/Body
@onready var _btn_close: Button = $Root/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_open_button_icon()
	_panel.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_open_btn.pressed.connect(_on_open_pressed)
	_btn_close.pressed.connect(_on_close_pressed)

	var hints := get_node_or_null("/root/ATKHints")
	if hints != null:
		if hints.has_signal("hint_delivered"):
			hints.hint_delivered.connect(_on_hint_delivered)
		if hints.has_signal("hint_request_failed"):
			hints.hint_request_failed.connect(_on_hint_request_failed)

	if not keyboard_action.strip_edges().is_empty():
		ATKUiInputActions.ensure_action_with_default_key(keyboard_action, _DEFAULT_TOGGLE_KEY)


func is_hint_panel_open() -> bool:
	return _panel.visible


func set_hud_layer_visible(on: bool) -> void:
	visible = on
	if not on:
		_hide_panel()


func _on_open_pressed() -> void:
	var hints := get_node_or_null("/root/ATKHints")
	if hints != null and hints.has_method("request_next_hint"):
		hints.call("request_next_hint")


func _on_hint_delivered(bank_id: String, _layer_index: int, text: String, is_last: bool) -> void:
	var bank_name := bank_id
	var hints := get_node_or_null("/root/ATKHints")
	if hints != null and hints.has_method("get_hint_bank"):
		var b: Variant = hints.call("get_hint_bank", bank_id)
		if b is ATKHintBank and not (b as ATKHintBank).display_name.strip_edges().is_empty():
			bank_name = (b as ATKHintBank).display_name.strip_edges()
	_title.text = "Hint" if bank_name.is_empty() else ("Hint — %s" % bank_name)
	if is_last:
		_title.text += " (last)"
	_body.clear()
	_body.add_text(text)
	_show_panel()


func _on_hint_request_failed(reason_code: String, detail: String) -> void:
	_title.text = "Hint"
	var msg := ""
	match reason_code:
		"no_bank":
			msg = "No hint is available for this situation right now."
		"missing_bank":
			msg = "Hint data is not registered for '%s'." % detail
		"empty_bank":
			msg = "This hint set has no lines yet."
		"exhausted":
			msg = "There are no more hints for this puzzle or scene."
		"cooldown":
			msg = "Wait %s s before the next hint." % detail
		_:
			msg = "Could not show a hint (%s)." % reason_code
	_body.clear()
	_body.add_text(msg)
	_show_panel()


func _show_panel() -> void:
	_panel.visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_close.call_deferred("grab_focus")


func _hide_panel() -> void:
	_panel.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_close_pressed() -> void:
	_hide_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not allow_keyboard_hint:
		return
	if not _keyboard_shortcuts_allowed():
		return
	if keyboard_action.strip_edges().is_empty():
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not event.is_action_pressed(StringName(keyboard_action)):
		return
	var hints := get_node_or_null("/root/ATKHints")
	if hints != null and hints.has_method("request_next_hint"):
		hints.call("request_next_hint")
	get_viewport().set_input_as_handled()


func _apply_open_button_icon() -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.35, 0.45))
	for y in range(10, 38):
		for x in range(14, 34):
			img.set_pixel(x, y, Color(0.92, 0.93, 0.96))
	_open_btn.texture_normal = ImageTexture.create_from_image(img)


func _keyboard_shortcuts_allowed() -> bool:
	var settings := get_node_or_null("/root/ATKSettings")
	if settings == null or not settings.has_method("is_keyboard_shortcuts_enabled"):
		return true
	return bool(settings.call("is_keyboard_shortcuts_enabled"))
