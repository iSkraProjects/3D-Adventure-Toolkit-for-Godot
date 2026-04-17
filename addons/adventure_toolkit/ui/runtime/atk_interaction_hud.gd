extends CanvasLayer
class_name ATKInteractionHud

## Root node for **interaction-related UI** (toast copy, future verb wheel, etc.). Put every piece
## under this layer so you can instance one scene under your game UI and keep things organized.
## The default instance listens to [ATKInteractionFeedback.message_shown] on [code]/root[/code].
## Dismiss with **Continue** (or [kbd]ui_accept[/kbd] via the button shortcut), or click the dimmed area outside the panel.
## The timer still hides the panel after [member display_seconds] if nothing is pressed.


@export var display_seconds := 5.0
## Delay before the Continue button accepts input / focus. Avoids the mouse-up from a world click
## (e.g. picking up an object) immediately dismissing the panel.
@export var continue_arm_delay_sec := 0.2

@onready var _modal_dismiss: ColorRect = $HudRoot/ModalDismissLayer
@onready var _panel: PanelContainer = $HudRoot/FeedbackAnchor/Panel
@onready var _title: Label = $HudRoot/FeedbackAnchor/Panel/Margin/VBox/Title
@onready var _body: RichTextLabel = $HudRoot/FeedbackAnchor/Panel/Margin/VBox/Body
@onready var _btn_continue: Button = $HudRoot/FeedbackAnchor/Panel/Margin/VBox/ContinueButton
@onready var _timer: Timer = $HideTimer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 16
	_timer.wait_time = maxf(0.5, display_seconds)
	_timer.one_shot = true
	_timer.timeout.connect(_on_hide_timer)
	_panel.visible = false
	if is_instance_valid(_modal_dismiss):
		_modal_dismiss.visible = false
		_modal_dismiss.gui_input.connect(_on_modal_dismiss_gui_input)
	_btn_continue.pressed.connect(_on_continue_pressed)

	var bus := get_node_or_null("/root/ATKInteractionFeedback")
	if bus != null and bus.has_signal("message_shown"):
		bus.message_shown.connect(_on_message_shown)
	var settings := get_node_or_null("/root/ATKSettings")
	if settings != null and settings.has_signal("accessibility_changed"):
		settings.accessibility_changed.connect(_on_accessibility_changed)
	_apply_settings_to_ui()


func _on_message_shown(text: String, title: String, _object_id: String) -> void:
	var resolved_title := _resolve_text(title)
	var resolved_text := _resolve_text(text)
	_title.visible = not resolved_title.is_empty()
	_title.text = resolved_title if not resolved_title.is_empty() else ""
	_body.clear()
	_body.add_text(resolved_text)
	_panel.visible = true
	if is_instance_valid(_modal_dismiss):
		_modal_dismiss.visible = true
	_timer.stop()
	_timer.start()
	_btn_continue.disabled = true
	call_deferred("_begin_continue_arm")


func _begin_continue_arm() -> void:
	await get_tree().create_timer(maxf(0.05, continue_arm_delay_sec), true).timeout
	if not is_instance_valid(self) or not is_instance_valid(_btn_continue) or not is_instance_valid(_panel):
		return
	if not _panel.visible:
		return
	_btn_continue.disabled = false
	_btn_continue.grab_focus()


func _on_continue_pressed() -> void:
	_hide_feedback()


func _on_modal_dismiss_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _panel.visible:
		return
	if _btn_continue.disabled:
		return
	_hide_feedback()
	get_viewport().set_input_as_handled()


func _on_hide_timer() -> void:
	_hide_feedback()


func _hide_feedback() -> void:
	var was_visible := is_instance_valid(_panel) and _panel.visible
	_timer.stop()
	if is_instance_valid(_modal_dismiss):
		_modal_dismiss.visible = false
	if is_instance_valid(_panel):
		_panel.visible = false
	if is_instance_valid(_btn_continue):
		_btn_continue.disabled = false
	if was_visible:
		var bus := get_node_or_null("/root/ATKInteractionFeedback")
		if bus != null and bus.has_signal("message_dismissed"):
			bus.message_dismissed.emit()


func is_feedback_panel_open() -> bool:
	return is_instance_valid(_panel) and _panel.visible


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
		_title.scale = Vector2(s, s)
		_body.scale = Vector2(s, s)
