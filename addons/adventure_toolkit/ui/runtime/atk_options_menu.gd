extends CanvasLayer
class_name ATKOptionsMenu

signal closed

const _ACTIONS := [
	"atk_toggle_inventory",
	"atk_pause_menu",
	"atk_toggle_journal",
	"atk_request_hint",
	"atk_toggle_save_menu",
]

var _capture_action := ""
var _key_buttons: Dictionary = {}
var _is_binding_ui := false
var _resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var _root: Control
var _panel: PanelContainer
var _resolution: OptionButton
var _master: HSlider
var _music: HSlider
var _sfx: HSlider
var _ambience: HSlider
var _voice: HSlider
var _keyboard_toggle: CheckBox
var _close_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	layer = 120
	visible = false
	_build_ui()
	_bind_from_settings()


func open_menu() -> void:
	_bind_from_settings()
	visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_btn.grab_focus()


func close_menu() -> void:
	visible = false
	_capture_action = ""
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emit_signal("closed")


func _unhandled_input(event: InputEvent) -> void:
	if _capture_action.is_empty():
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var settings := _settings()
	if settings == null:
		return
	settings.set_action_key_binding(_capture_action, key_event.physical_keycode, true)
	_capture_action = ""
	_refresh_keybind_labels()
	get_viewport().set_input_as_handled()


func _settings() -> Node:
	return get_node_or_null("/root/ATKSettings")


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 520)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-320, -260)
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	var title := Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	v.add_child(title)

	_resolution = OptionButton.new()
	for r in _resolutions:
		_resolution.add_item("%dx%d" % [r.x, r.y])
	v.add_child(_labeled("Resolution", _resolution))
	_resolution.item_selected.connect(_on_resolution_selected)

	_master = _make_slider()
	_music = _make_slider()
	_sfx = _make_slider()
	_ambience = _make_slider()
	_voice = _make_slider()
	v.add_child(_labeled("Master Volume", _master))
	v.add_child(_labeled("Music Volume", _music))
	v.add_child(_labeled("SFX Volume", _sfx))
	v.add_child(_labeled("Ambience Volume", _ambience))
	v.add_child(_labeled("Voice Volume", _voice))
	_master.value_changed.connect(_on_audio_slider_changed)
	_music.value_changed.connect(_on_audio_slider_changed)
	_sfx.value_changed.connect(_on_audio_slider_changed)
	_ambience.value_changed.connect(_on_audio_slider_changed)
	_voice.value_changed.connect(_on_audio_slider_changed)

	_keyboard_toggle = CheckBox.new()
	_keyboard_toggle.text = "Enable keyboard shortcuts"
	_keyboard_toggle.toggled.connect(_on_keyboard_toggle_changed)
	v.add_child(_keyboard_toggle)

	var keybinds_title := Label.new()
	keybinds_title.text = "Keybinds"
	v.add_child(keybinds_title)

	for action in _ACTIONS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(260, 0)
		btn.pressed.connect(func() -> void: _begin_capture(action))
		_key_buttons[action] = btn
		v.add_child(_labeled(action, btn))

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(close_menu)
	v.add_child(_close_btn)


func _labeled(label_text: String, control: Control) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(220, 0)
	hb.add_child(l)
	hb.add_child(control)
	return hb


func _make_slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _bind_from_settings() -> void:
	var settings := _settings()
	if settings == null:
		return
	_is_binding_ui = true
	var res: Vector2i = settings.get_resolution()
	var picked := 0
	for i in _resolutions.size():
		if _resolutions[i] == res:
			picked = i
			break
	_resolution.select(picked)
	_master.value = settings.get_master_volume()
	_music.value = settings.get_music_volume()
	_sfx.value = settings.get_sfx_volume()
	_ambience.value = settings.get_ambience_volume()
	_voice.value = settings.get_voice_volume()
	_keyboard_toggle.button_pressed = settings.is_keyboard_shortcuts_enabled()
	_refresh_keybind_labels()
	_is_binding_ui = false


func _refresh_keybind_labels() -> void:
	for action in _ACTIONS:
		var btn := _key_buttons.get(action, null)
		if btn == null:
			continue
		btn.text = _action_label(action)


func _action_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	var e := events[0]
	if e is InputEventKey:
		var ek := e as InputEventKey
		return OS.get_keycode_string(ek.physical_keycode)
	return e.as_text()


func _begin_capture(action: String) -> void:
	_capture_action = action
	var btn := _key_buttons.get(action, null)
	if btn != null:
		btn.text = "Press any key..."


func _on_resolution_selected(index: int) -> void:
	if _is_binding_ui:
		return
	var settings := _settings()
	if settings == null:
		return
	var r: Vector2i = _resolutions[index]
	settings.set_resolution(r.x, r.y, true)


func _on_audio_slider_changed(_v: float) -> void:
	if _is_binding_ui:
		return
	var settings := _settings()
	if settings == null:
		return
	settings.set_audio_volumes(_master.value, _music.value, _sfx.value, _voice.value, true, _ambience.value)


func _on_keyboard_toggle_changed(on: bool) -> void:
	if _is_binding_ui:
		return
	var settings := _settings()
	if settings == null:
		return
	settings.set_keyboard_shortcuts_enabled(on, true)
