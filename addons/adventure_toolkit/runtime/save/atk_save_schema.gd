class_name ATKSaveSchema
extends RefCounted


const SAVE_SCHEMA_VERSION := 1
const SETTINGS_SCHEMA_VERSION := 1


static func create_empty_save(slot_id: String) -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"slot_id": slot_id,
		"metadata": create_save_metadata(slot_id),
		"state": {
			"global": {},
			"scene": {},
			"object": {},
			"session": {},
		},
		"runtime": {
			"scene_id": "",
			"spawn_id": "",
			"has_player_transform": false,
			"player_position": {"x": 0.0, "y": 0.0, "z": 0.0},
			"player_rotation": {"x": 0.0, "y": 0.0, "z": 0.0},
		},
		"inventory": {
			"items": {},
			"selected_item_id": "",
		},
		"quests": {
			"v": 2,
			"entries": {},
		},
		"journal": {
			"v": 1,
			"entries": [],
		},
		"hints": {
			"v": 1,
			"progress": {},
		},
		"episodes": {
			"v": 1,
			"active_episode_id": "",
		},
	}


static func create_save_metadata(slot_id: String) -> Dictionary:
	return {
		"slot_id": slot_id,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"display_timestamp": Time.get_datetime_string_from_system(true, true),
		"label": "Save %s" % slot_id,
	}


static func create_default_settings() -> Dictionary:
	return {
		"schema_version": SETTINGS_SCHEMA_VERSION,
		"audio": {
			"master_volume": 1.0,
			"music_volume": 0.5,
			"sfx_volume": 0.5,
			"ambience_volume": 0.5,
			"voice_volume": 0.5,
		},
		"gameplay": {
			"text_speed": 1.0,
		},
		"localization": {
			"locale": "en",
		},
		"accessibility": {
			"subtitle_scale": 1.0,
			"text_speed": 1.0,
		},
		"input": {
			"allow_rebind": true,
			"keyboard_shortcuts_enabled": true,
			"action_overrides": {},
		},
		"video": {
			"resolution": {"width": 1280, "height": 720},
		},
	}


static func is_valid_save_payload(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if not payload.has("schema_version"):
		return false
	if int(payload.get("schema_version", -1)) < 1:
		return false
	if not payload.has("state"):
		return false
	if not payload.has("runtime"):
		return false
	return true


static func is_valid_settings_payload(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if int(payload.get("schema_version", -1)) < 1:
		return false
	return true
