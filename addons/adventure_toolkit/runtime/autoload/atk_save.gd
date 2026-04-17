extends Node


signal save_started(slot_id: String)
signal save_finished(slot_id: String, success: bool, message: String)
signal load_started(slot_id: String)
signal load_finished(slot_id: String, success: bool, message: String)
signal delete_finished(slot_id: String, success: bool, message: String)
signal settings_saved(success: bool, message: String)
signal settings_loaded(success: bool, message: String)


const SAVE_DIRECTORY := "user://atk_saves"
const SETTINGS_PATH := "user://atk_settings.json"

var _is_restoring := false

const _DEFAULT_SAVE_UI := preload("res://addons/adventure_toolkit/ui/runtime/atk_save_ui.tscn")
const _DEFAULT_PAUSE_UI := preload("res://addons/adventure_toolkit/ui/runtime/atk_pause_overlay.tscn")


func _ready() -> void:
	_ensure_save_directory()
	var save_ui := _DEFAULT_SAVE_UI.instantiate()
	save_ui.name = "DefaultSaveUI"
	add_child(save_ui)
	var pause_ui := _DEFAULT_PAUSE_UI.instantiate()
	pause_ui.name = "DefaultPauseOverlay"
	add_child(pause_ui)


func save_slot(slot_id: String) -> bool:
	emit_signal("save_started", slot_id)

	var payload := capture_snapshot(slot_id)
	var path := get_slot_path(slot_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error_message := "Failed to open save slot '%s' for writing." % slot_id
		ATKLog.error(error_message, "ATKSave")
		emit_signal("save_finished", slot_id, false, error_message)
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	var success_message := "Saved slot '%s'." % slot_id
	ATKLog.info(success_message, "ATKSave")
	emit_signal("save_finished", slot_id, true, success_message)
	return true


func load_slot(slot_id: String) -> Dictionary:
	return _read_slot_payload(slot_id, true)


## Reads a slot file. When [param emit_load_signals] is [code]false[/code], does not emit
## [signal load_started] / [signal load_finished] or log success — used for UI metadata listing
## so listeners (e.g. save panel refresh) cannot recurse into [method load_slot].
func _read_slot_payload(slot_id: String, emit_load_signals: bool) -> Dictionary:
	if emit_load_signals:
		emit_signal("load_started", slot_id)

	var path := get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		var message := "Save slot '%s' does not exist." % slot_id
		if emit_load_signals:
			ATKLog.warn(message, "ATKSave")
			emit_signal("load_finished", slot_id, false, message)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error := "Failed to open save slot '%s'." % slot_id
		if emit_load_signals:
			ATKLog.error(open_error, "ATKSave")
			emit_signal("load_finished", slot_id, false, open_error)
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed := JSON.parse_string(text)
	if not (parsed is Dictionary):
		var parse_error := "Save slot '%s' has invalid JSON payload." % slot_id
		if emit_load_signals:
			ATKLog.error(parse_error, "ATKSave")
			emit_signal("load_finished", slot_id, false, parse_error)
		return {}

	var payload: Dictionary = parsed
	if not ATKSaveSchema.is_valid_save_payload(payload):
		var validation_error := "Save slot '%s' failed schema validation." % slot_id
		if emit_load_signals:
			ATKLog.error(validation_error, "ATKSave")
			emit_signal("load_finished", slot_id, false, validation_error)
		return {}

	if emit_load_signals:
		var success_message := "Loaded slot '%s'." % slot_id
		ATKLog.info(success_message, "ATKSave")
		emit_signal("load_finished", slot_id, true, success_message)
	return payload


func load_slot_and_restore(slot_id: String) -> bool:
	if _is_restoring:
		ATKLog.warn("Load ignored: restore already in progress.", "ATKSave")
		return false

	var payload := load_slot(slot_id)
	if payload.is_empty():
		return false

	return await restore_snapshot(payload)


func capture_snapshot(slot_id: String) -> Dictionary:
	var payload := ATKSaveSchema.create_empty_save(slot_id)
	payload["metadata"] = ATKSaveSchema.create_save_metadata(slot_id)

	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes != null:
		var runtime: Dictionary = payload.get("runtime", {}).duplicate(true)
		runtime["scene_id"] = scenes.current_scene_id
		runtime["spawn_id"] = scenes.current_spawn_id
		_capture_player_transform(runtime)
		payload["runtime"] = runtime

	var state := get_node_or_null("/root/ATKState")
	if state != null:
		var exported: Dictionary = state.export_state()
		var state_payload := payload.get("state", {})
		state_payload["global"] = exported.get("global", {})
		state_payload["scene"] = exported.get("scene", {})
		state_payload["object"] = exported.get("object", {})
		state_payload["session"] = exported.get("session", {})
		payload["state"] = state_payload

	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory != null:
		payload["inventory"] = inventory.export_inventory_state()

	var quests := get_node_or_null("/root/ATKQuests")
	if quests != null and quests.has_method("export_quest_save"):
		payload["quests"] = quests.call("export_quest_save")

	var journal := get_node_or_null("/root/ATKJournal")
	if journal != null and journal.has_method("export_journal_state"):
		payload["journal"] = journal.call("export_journal_state")

	var hints := get_node_or_null("/root/ATKHints")
	if hints != null and hints.has_method("export_hints_state"):
		payload["hints"] = hints.call("export_hints_state")

	var episodes := get_node_or_null("/root/ATKEpisodes")
	if episodes != null and episodes.has_method("get_active_episode_id"):
		payload["episodes"] = {
			"v": 1,
			"active_episode_id": str(episodes.call("get_active_episode_id")),
		}

	return payload


func restore_snapshot(payload: Dictionary) -> bool:
	_is_restoring = true
	if not ATKSaveSchema.is_valid_save_payload(payload):
		ATKLog.error("Cannot restore snapshot: invalid payload.", "ATKSave")
		_is_restoring = false
		return false

	var state := get_node_or_null("/root/ATKState")
	if state != null:
		var imported_state := payload.get("state", {})
		state.import_state({
			"global": imported_state.get("global", {}),
			"scene": imported_state.get("scene", {}),
			"object": imported_state.get("object", {}),
			"session": imported_state.get("session", {}),
		})

	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory != null:
		var inventory_payload := payload.get("inventory", {})
		inventory.import_inventory_state(inventory_payload)

	var quests := get_node_or_null("/root/ATKQuests")
	if quests != null and quests.has_method("import_quest_save"):
		var quest_payload: Variant = payload.get("quests", {})
		if quest_payload is Dictionary:
			quests.call("import_quest_save", quest_payload)

	var journal := get_node_or_null("/root/ATKJournal")
	if journal != null and journal.has_method("import_journal_state"):
		var journal_payload: Variant = payload.get("journal", {})
		if journal_payload is Dictionary:
			journal.call("import_journal_state", journal_payload)

	var hints := get_node_or_null("/root/ATKHints")
	if hints != null and hints.has_method("import_hints_state"):
		var hints_payload: Variant = payload.get("hints", {})
		if hints_payload is Dictionary:
			hints.call("import_hints_state", hints_payload)

	var episodes := get_node_or_null("/root/ATKEpisodes")
	if episodes != null and episodes.has_method("set_active_episode"):
		var episodes_payload: Variant = payload.get("episodes", {})
		if episodes_payload is Dictionary:
			episodes.call("set_active_episode", str((episodes_payload as Dictionary).get("active_episode_id", "")))

	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null:
		ATKLog.warn("ATKScenes is not available. State restored without scene transition.", "ATKSave")
		_is_restoring = false
		return true

	var runtime := payload.get("runtime", {})
	var scene_id: String = runtime.get("scene_id", "")
	var spawn_id: String = runtime.get("spawn_id", "")

	if scene_id.is_empty():
		ATKLog.warn("Snapshot has no scene_id. State restored without scene transition.", "ATKSave")
		_is_restoring = false
		return true

	if not scenes.has_scene(scene_id):
		ATKLog.error("Cannot restore scene '%s': not registered in ATKScenes." % scene_id, "ATKSave")
		_is_restoring = false
		return false

	var load_error: int = await scenes.load_scene(scene_id, spawn_id)
	if load_error != OK:
		ATKLog.error("Failed to restore scene '%s' from snapshot." % scene_id, "ATKSave")
		_is_restoring = false
		return false

	# Let ATKSceneRoot apply spawn, then override with exact saved transform.
	await get_tree().process_frame
	await get_tree().process_frame
	await _apply_saved_player_transform(runtime)

	ATKLog.info("Snapshot restored to scene '%s' spawn '%s'." % [scene_id, spawn_id], "ATKSave")
	_is_restoring = false
	return true


func _capture_player_transform(runtime: Dictionary) -> void:
	var player := _find_player_node3d()
	if player == null:
		runtime["has_player_transform"] = false
		return
	runtime["has_player_transform"] = true
	runtime["player_position"] = ATKSerialize.vec3_to_dict(player.global_position)
	runtime["player_rotation"] = ATKSerialize.vec3_to_dict(player.global_rotation)


func _apply_saved_player_transform(runtime: Dictionary) -> void:
	if not bool(runtime.get("has_player_transform", false)):
		return
	var pos := ATKSerialize.vec3_from_dict(runtime.get("player_position", {}))
	var rot := ATKSerialize.vec3_from_dict(runtime.get("player_rotation", {}))
	var player := _find_player_node3d()
	if player == null:
		ATKLog.warn("Save has player transform but no atk_player Node3D was found.", "ATKSave")
		return
	player.global_position = pos
	player.global_rotation = rot
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	var agent := player.find_child("NavigationAgent3D", true, false)
	if agent is NavigationAgent3D:
		(agent as NavigationAgent3D).target_position = pos
	ATKLog.debug("Restored player transform %s / %s." % [str(pos), str(rot)], "ATKSave")


func _find_player_node3d() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("atk_player"):
		if n is Node3D:
			return n as Node3D
	return null


func save_settings(settings: Dictionary) -> bool:
	var payload := settings.duplicate(true)
	if not payload.has("schema_version"):
		payload["schema_version"] = ATKSaveSchema.SETTINGS_SCHEMA_VERSION

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		var error_message := "Failed to open settings file for writing."
		ATKLog.error(error_message, "ATKSave")
		emit_signal("settings_saved", false, error_message)
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	ATKLog.info("Settings saved.", "ATKSave")
	emit_signal("settings_saved", true, "Settings saved.")
	return true


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		var default_settings := ATKSaveSchema.create_default_settings()
		emit_signal("settings_loaded", true, "Default settings created.")
		return default_settings

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		var error_message := "Failed to open settings file."
		ATKLog.error(error_message, "ATKSave")
		emit_signal("settings_loaded", false, error_message)
		return ATKSaveSchema.create_default_settings()

	var text := file.get_as_text()
	file.close()

	var parsed := JSON.parse_string(text)
	if not (parsed is Dictionary):
		var parse_error := "Settings payload has invalid JSON."
		ATKLog.error(parse_error, "ATKSave")
		emit_signal("settings_loaded", false, parse_error)
		return ATKSaveSchema.create_default_settings()

	var payload: Dictionary = parsed
	if not ATKSaveSchema.is_valid_settings_payload(payload):
		var validation_error := "Settings payload failed schema validation."
		ATKLog.error(validation_error, "ATKSave")
		emit_signal("settings_loaded", false, validation_error)
		return ATKSaveSchema.create_default_settings()

	ATKLog.info("Settings loaded.", "ATKSave")
	emit_signal("settings_loaded", true, "Settings loaded.")
	return payload


func get_slot_path(slot_id: String) -> String:
	_ensure_save_directory()
	return "%s/%s.json" % [SAVE_DIRECTORY, slot_id]


func has_slot(slot_id: String) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_id))


## Permanently removes the save file for [param slot_id]. Emits [signal delete_finished].
func delete_slot(slot_id: String) -> bool:
	var sid := slot_id.strip_edges()
	if sid.is_empty():
		return false

	var path := get_slot_path(sid)
	if not FileAccess.file_exists(path):
		var m2 := "Save slot '%s' does not exist." % sid
		ATKLog.warn(m2, "ATKSave")
		emit_signal("delete_finished", sid, false, m2)
		return false

	var err: Error = DirAccess.remove_absolute(path)
	if err != OK:
		var m3 := "Failed to delete '%s': %s" % [sid, error_string(err)]
		ATKLog.error(m3, "ATKSave")
		emit_signal("delete_finished", sid, false, m3)
		return false

	var ok_msg := "Save slot '%s' deleted." % sid
	ATKLog.info(ok_msg, "ATKSave")
	emit_signal("delete_finished", sid, true, ok_msg)
	return true


func list_slots() -> PackedStringArray:
	_ensure_save_directory()
	var slots := PackedStringArray()
	var dir := DirAccess.open(SAVE_DIRECTORY)
	if dir == null:
		return slots

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			slots.append(file_name.trim_suffix(".json"))
		file_name = dir.get_next()
	dir.list_dir_end()

	return slots


func get_slot_metadata(slot_id: String) -> Dictionary:
	var payload := _read_slot_payload(slot_id, false)
	if payload.is_empty():
		return {}
	return payload.get("metadata", {})


func list_slot_metadata() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for slot_id in list_slots():
		var metadata := get_slot_metadata(slot_id)
		if metadata.is_empty():
			continue
		entries.append(metadata)
	return entries


func _ensure_save_directory() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
