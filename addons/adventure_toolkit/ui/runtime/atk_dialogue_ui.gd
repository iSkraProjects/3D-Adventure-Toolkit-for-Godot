extends CanvasLayer

## Default dialogue UI (Phase 14 / T14.2). Listens to [ATKDialogue] signals and calls
## [method ATKDialogue.submit_continue] / [method ATKDialogue.submit_choice].
## Clicking the dimmed area outside the speech panel advances a line (same as Continue), but not during choice lists.


@onready var _root: Control = $Root
@onready var _speaker: Label = $Root/DialogueAnchor/Panel/Margin/VBox/Speaker
@onready var _body: RichTextLabel = $Root/DialogueAnchor/Panel/Margin/VBox/Body
@onready var _btn_continue: Button = $Root/DialogueAnchor/Panel/Margin/VBox/ContinueButton
@onready var _choices: VBoxContainer = $Root/DialogueAnchor/Panel/Margin/VBox/Choices


func _ready() -> void:
	visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_continue.visible = false
	_clear_choice_buttons()

	var dlg := get_node_or_null("/root/ATKDialogue")
	if dlg == null:
		push_warning("ATKDialogueUI: ATKDialogue autoload missing.")
		return

	dlg.dialogue_started.connect(_on_dialogue_started)
	dlg.line_shown.connect(_on_line_shown)
	dlg.choices_shown.connect(_on_choices_shown)
	dlg.dialogue_finished.connect(_on_dialogue_finished)
	_btn_continue.pressed.connect(_on_continue_pressed)
	_root.gui_input.connect(_on_root_gui_input)
	_apply_settings_to_ui()
	var settings := get_node_or_null("/root/ATKSettings")
	if settings != null and settings.has_signal("accessibility_changed"):
		settings.accessibility_changed.connect(_on_accessibility_changed)


func _on_root_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _choices.get_child_count() > 0:
		return
	if not _btn_continue.visible:
		return
	_on_continue_pressed()
	get_viewport().set_input_as_handled()


func _on_dialogue_started(_definition_id: String) -> void:
	visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_choice_buttons()
	_btn_continue.visible = false


func _on_line_shown(_node_id: String, speaker: String, line_text: String) -> void:
	_clear_choice_buttons()
	var speaker_text := _resolve_text(speaker).strip_edges()
	_speaker.text = speaker_text if not speaker_text.is_empty() else "…"
	_body.clear()
	_body.add_text(_resolve_text(line_text).strip_edges())
	_btn_continue.visible = true
	_btn_continue.grab_focus()


func _on_choices_shown(_node_id: String, choice_labels: PackedStringArray) -> void:
	_btn_continue.visible = false
	_clear_choice_buttons()
	for i in range(choice_labels.size()):
		var b := Button.new()
		b.text = _resolve_text(choice_labels[i])
		var idx := i
		b.pressed.connect(func() -> void: _on_choice_pressed(idx))
		_choices.add_child(b)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Control).grab_focus()


func _on_dialogue_finished(_definition_id: String) -> void:
	visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_choice_buttons()
	_btn_continue.visible = false


func _on_continue_pressed() -> void:
	var dlg := get_node_or_null("/root/ATKDialogue")
	if dlg != null and dlg.has_method("submit_continue"):
		dlg.submit_continue()


func _on_choice_pressed(ui_index: int) -> void:
	var dlg := get_node_or_null("/root/ATKDialogue")
	if dlg != null and dlg.has_method("submit_choice"):
		dlg.submit_choice(ui_index)


func _clear_choice_buttons() -> void:
	for c in _choices.get_children():
		c.queue_free()


func _resolve_text(raw: String) -> String:
	var settings := get_node_or_null("/root/ATKSettings")
	if settings != null and settings.has_method("resolve_text"):
		return str(settings.call("resolve_text", raw))
	return raw


func _on_accessibility_changed(_subtitle_scale: float, _text_speed: float) -> void:
	_apply_settings_to_ui()


func _apply_settings_to_ui() -> void:
	_btn_continue.text = _resolve_text("tr:ui_continue")
	var settings := get_node_or_null("/root/ATKSettings")
	if settings != null and settings.has_method("get_subtitle_scale"):
		var s := float(settings.call("get_subtitle_scale"))
		_speaker.scale = Vector2(s, s)
		_body.scale = Vector2(s, s)
