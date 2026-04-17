extends Node

## Phase 22 baseline: localization + accessibility + remap-ready input hooks.

signal settings_loaded(settings: Dictionary)
signal settings_changed(settings: Dictionary)
signal localization_changed(locale: String)
signal accessibility_changed(subtitle_scale: float, text_speed: float)
signal input_bindings_changed
signal audio_settings_changed(master: float, music: float, sfx: float, ambience: float, voice: float)
signal video_settings_changed(width: int, height: int)

const SECTION_LOCALIZATION := "localization"
const SECTION_ACCESSIBILITY := "accessibility"
const SECTION_INPUT := "input"
const SECTION_AUDIO := "audio"
const SECTION_VIDEO := "video"

var _settings: Dictionary = {}


func _ready() -> void:
	_settings = _load_or_default_settings()
	_repair_zeroed_audio_on_migration()
	_apply_all_settings()
	emit_signal("settings_loaded", _settings.duplicate(true))
	set_process_unhandled_input(true)


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func save_now() -> bool:
	var saver := get_node_or_null("/root/ATKSave")
	if saver == null or not saver.has_method("save_settings"):
		ATKLog.warn("ATKSave unavailable; cannot persist settings.", "ATKSettings")
		return false
	var ok: bool = saver.call("save_settings", _settings.duplicate(true))
	if ok:
		emit_signal("settings_changed", _settings.duplicate(true))
	return ok


func resolve_text(raw: String) -> String:
	var text := raw.strip_edges()
	if text.begins_with("tr:"):
		return tr(text.trim_prefix("tr:"))
	return raw


func get_subtitle_scale() -> float:
	var accessibility: Dictionary = _settings.get(SECTION_ACCESSIBILITY, {})
	return clampf(float(accessibility.get("subtitle_scale", 1.0)), 0.6, 2.5)


func set_subtitle_scale(value: float, save := true) -> void:
	var accessibility: Dictionary = (_settings.get(SECTION_ACCESSIBILITY, {}) as Dictionary).duplicate(true)
	accessibility["subtitle_scale"] = clampf(value, 0.6, 2.5)
	_settings[SECTION_ACCESSIBILITY] = accessibility
	_apply_accessibility()
	if save:
		save_now()


func get_text_speed() -> float:
	var accessibility: Dictionary = _settings.get(SECTION_ACCESSIBILITY, {})
	return clampf(float(accessibility.get("text_speed", 1.0)), 0.2, 3.0)


func set_text_speed(value: float, save := true) -> void:
	var accessibility: Dictionary = (_settings.get(SECTION_ACCESSIBILITY, {}) as Dictionary).duplicate(true)
	accessibility["text_speed"] = clampf(value, 0.2, 3.0)
	_settings[SECTION_ACCESSIBILITY] = accessibility
	_apply_accessibility()
	if save:
		save_now()


func get_locale() -> String:
	var localization: Dictionary = _settings.get(SECTION_LOCALIZATION, {})
	return str(localization.get("locale", "en"))


func set_locale(locale: String, save := true) -> void:
	var localization: Dictionary = (_settings.get(SECTION_LOCALIZATION, {}) as Dictionary).duplicate(true)
	localization["locale"] = locale.strip_edges()
	_settings[SECTION_LOCALIZATION] = localization
	_apply_localization()
	if save:
		save_now()


func is_keyboard_shortcuts_enabled() -> bool:
	var input_section: Dictionary = _settings.get(SECTION_INPUT, {})
	return bool(input_section.get("keyboard_shortcuts_enabled", true))


func set_keyboard_shortcuts_enabled(enabled: bool, save := true) -> void:
	var input_section: Dictionary = (_settings.get(SECTION_INPUT, {}) as Dictionary).duplicate(true)
	input_section["keyboard_shortcuts_enabled"] = enabled
	_settings[SECTION_INPUT] = input_section
	if save:
		save_now()
	emit_signal("input_bindings_changed")


func get_master_volume() -> float:
	var audio: Dictionary = _settings.get(SECTION_AUDIO, {})
	return clampf(float(audio.get("master_volume", 1.0)), 0.0, 1.0)


func get_music_volume() -> float:
	var audio: Dictionary = _settings.get(SECTION_AUDIO, {})
	return clampf(float(audio.get("music_volume", 1.0)), 0.0, 1.0)


func get_sfx_volume() -> float:
	var audio: Dictionary = _settings.get(SECTION_AUDIO, {})
	return clampf(float(audio.get("sfx_volume", 1.0)), 0.0, 1.0)


func get_voice_volume() -> float:
	var audio: Dictionary = _settings.get(SECTION_AUDIO, {})
	return clampf(float(audio.get("voice_volume", 1.0)), 0.0, 1.0)


func get_ambience_volume() -> float:
	var audio: Dictionary = _settings.get(SECTION_AUDIO, {})
	return clampf(float(audio.get("ambience_volume", 1.0)), 0.0, 1.0)


func set_audio_volumes(master: float, music: float, sfx: float, voice: float, save := true, ambience: float = -1.0) -> void:
	var audio: Dictionary = (_settings.get(SECTION_AUDIO, {}) as Dictionary).duplicate(true)
	audio["master_volume"] = clampf(master, 0.0, 1.0)
	audio["music_volume"] = clampf(music, 0.0, 1.0)
	audio["sfx_volume"] = clampf(sfx, 0.0, 1.0)
	audio["ambience_volume"] = clampf(ambience if ambience >= 0.0 else sfx, 0.0, 1.0)
	audio["voice_volume"] = clampf(voice, 0.0, 1.0)
	_settings[SECTION_AUDIO] = audio
	_apply_audio_settings()
	if save:
		save_now()


func set_resolution(width: int, height: int, save := true) -> void:
	var w := maxi(640, width)
	var h := maxi(360, height)
	var video: Dictionary = (_settings.get(SECTION_VIDEO, {}) as Dictionary).duplicate(true)
	video["resolution"] = {"width": w, "height": h}
	_settings[SECTION_VIDEO] = video
	_apply_video_settings()
	if save:
		save_now()


func get_resolution() -> Vector2i:
	var video: Dictionary = _settings.get(SECTION_VIDEO, {})
	var res: Dictionary = video.get("resolution", {"width": 1280, "height": 720})
	return Vector2i(int(res.get("width", 1280)), int(res.get("height", 720)))


func set_action_key_binding(action_name: String, keycode: Key, save := true) -> void:
	var action := action_name.strip_edges()
	if action.is_empty():
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
	_set_action_override(action, [{"type": "key", "physical_keycode": int(keycode)}], save)
	emit_signal("input_bindings_changed")


func clear_action_binding_override(action_name: String, save := true) -> void:
	var action := action_name.strip_edges()
	if action.is_empty():
		return
	var input_section: Dictionary = (_settings.get(SECTION_INPUT, {}) as Dictionary).duplicate(true)
	var overrides: Dictionary = (input_section.get("action_overrides", {}) as Dictionary).duplicate(true)
	overrides.erase(action)
	input_section["action_overrides"] = overrides
	_settings[SECTION_INPUT] = input_section
	if save:
		save_now()
	emit_signal("input_bindings_changed")


func _load_or_default_settings() -> Dictionary:
	var saver := get_node_or_null("/root/ATKSave")
	if saver == null or not saver.has_method("load_settings"):
		return _with_required_sections({})
	var loaded: Variant = saver.call("load_settings")
	if loaded is Dictionary:
		return _with_required_sections((loaded as Dictionary).duplicate(true))
	return _with_required_sections({})


func _with_required_sections(settings: Dictionary) -> Dictionary:
	var gameplay: Dictionary = settings.get("gameplay", {})
	if not settings.has(SECTION_LOCALIZATION):
		settings[SECTION_LOCALIZATION] = {"locale": "en"}
	if not settings.has(SECTION_ACCESSIBILITY):
		settings[SECTION_ACCESSIBILITY] = {
			"subtitle_scale": 1.0,
			"text_speed": float(gameplay.get("text_speed", 1.0)),
		}
	if not settings.has(SECTION_INPUT):
		settings[SECTION_INPUT] = {
			"allow_rebind": true,
			"keyboard_shortcuts_enabled": true,
			"action_overrides": {},
		}
	if not settings.has(SECTION_AUDIO):
		settings[SECTION_AUDIO] = {
			"master_volume": 1.0,
			"music_volume": 0.5,
			"sfx_volume": 0.5,
			"ambience_volume": 0.5,
			"voice_volume": 0.5,
		}
	if not settings.has(SECTION_VIDEO):
		settings[SECTION_VIDEO] = {
			"resolution": {"width": 1280, "height": 720},
		}
	return settings


func _apply_all_settings() -> void:
	_apply_localization()
	_apply_accessibility()
	_apply_audio_settings()
	_apply_video_settings()
	_apply_input_overrides()


func _apply_localization() -> void:
	var locale := get_locale()
	if locale.is_empty():
		return
	TranslationServer.set_locale(locale)
	emit_signal("localization_changed", locale)


func _apply_accessibility() -> void:
	emit_signal("accessibility_changed", get_subtitle_scale(), get_text_speed())


func _apply_audio_settings() -> void:
	var master := get_master_volume()
	var music := get_music_volume()
	var sfx := get_sfx_volume()
	var ambience := get_ambience_volume()
	var voice := get_voice_volume()
	_apply_bus_volume("Master", master)
	_apply_bus_volume("Music", music)
	_apply_bus_volume("SFX", sfx)
	_apply_bus_volume("Ambience", ambience)
	_apply_bus_volume("Voice", voice)
	emit_signal("audio_settings_changed", master, music, sfx, ambience, voice)


func _apply_video_settings() -> void:
	# Godot editor embedded play window cannot be resized at runtime.
	if OS.has_feature("editor"):
		var root := get_tree().root
		if root != null:
			root.content_scale_size = get_resolution()
		return
	var size := get_resolution()
	var win := get_window()
	if win != null:
		win.size = size
		# Keep options behavior predictable; resolution changes should be visible in windowed mode.
		if win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			win.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_size(size, win.get_window_id())
	else:
		DisplayServer.window_set_size(size)
	emit_signal("video_settings_changed", size.x, size.y)


func _apply_input_overrides() -> void:
	var input_section: Dictionary = _settings.get(SECTION_INPUT, {})
	var overrides: Variant = input_section.get("action_overrides", {})
	if not (overrides is Dictionary):
		return
	var overrides_dict: Dictionary = overrides as Dictionary
	for action in overrides_dict.keys():
		var entries: Variant = overrides_dict.get(action, [])
		if not (entries is Array):
			continue
		var key_entries: Array = entries
		if not InputMap.has_action(str(action)):
			InputMap.add_action(str(action))
		InputMap.action_erase_events(str(action))
		for e in key_entries:
			if not (e is Dictionary):
				continue
			var d: Dictionary = e
			if str(d.get("type", "")) != "key":
				continue
			var code := int(d.get("physical_keycode", 0))
			if code <= 0:
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(str(action), ev)
	emit_signal("input_bindings_changed")


func _set_action_override(action_name: String, serialized_events: Array, save: bool) -> void:
	var input_section: Dictionary = (_settings.get(SECTION_INPUT, {}) as Dictionary).duplicate(true)
	var overrides: Dictionary = (input_section.get("action_overrides", {}) as Dictionary).duplicate(true)
	overrides[action_name] = serialized_events
	input_section["action_overrides"] = overrides
	_settings[SECTION_INPUT] = input_section
	if save:
		save_now()


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var db := linear_to_db(clampf(linear, 0.0, 1.0))
	AudioServer.set_bus_volume_db(index, db)


func _repair_zeroed_audio_on_migration() -> void:
	var audio: Dictionary = (_settings.get(SECTION_AUDIO, {}) as Dictionary).duplicate(true)
	if audio.is_empty():
		return
	var master := float(audio.get("master_volume", 1.0))
	var music := float(audio.get("music_volume", 0.5))
	var sfx := float(audio.get("sfx_volume", 0.5))
	var ambience := float(audio.get("ambience_volume", sfx))
	var voice := float(audio.get("voice_volume", 0.5))
	# If legacy/bad data left everything muted, recover to safe defaults once.
	if (master <= 0.0 and music <= 0.0 and sfx <= 0.0 and ambience <= 0.0 and voice <= 0.0) or (
		master >= 0.99 and music <= 0.0 and sfx <= 0.0 and ambience <= 0.0 and voice <= 0.0
	):
		audio["master_volume"] = 1.0
		audio["music_volume"] = 0.5
		audio["sfx_volume"] = 0.5
		audio["ambience_volume"] = 0.5
		audio["voice_volume"] = 0.5
		_settings[SECTION_AUDIO] = audio


func _unhandled_input(_event: InputEvent) -> void:
	return
