extends Node


signal global_changed(key: String, value: Variant, old_value: Variant)
signal scene_changed(scene_id: String, key: String, value: Variant, old_value: Variant)
signal object_changed(object_id: String, key: String, value: Variant, old_value: Variant)
signal session_changed(key: String, value: Variant, old_value: Variant)
signal state_changed(scope: String, owner_id: String, key: String, value: Variant, old_value: Variant)


var _global: Dictionary = {}
var _scene: Dictionary = {} # scene_id -> Dictionary
var _object: Dictionary = {} # object_id -> Dictionary
var _session: Dictionary = {}

var _dirty := false


func is_dirty() -> bool:
	return _dirty


func clear_dirty() -> void:
	_dirty = false


func get_global(key: String, default_value: Variant = null) -> Variant:
	return _global.get(key, default_value)


func has_global(key: String) -> bool:
	return _global.has(key)


func set_global(key: String, value: Variant) -> void:
	var old_value: Variant = _global.get(key, null)
	_global[key] = value
	_dirty = true
	emit_signal("global_changed", key, value, old_value)
	emit_signal("state_changed", "global", "", key, value, old_value)
	ATKLog.debug("Global '%s' = %s" % [key, str(value)], "ATKState")


func remove_global(key: String) -> void:
	if not _global.has(key):
		return
	var old_value: Variant = _global[key]
	_global.erase(key)
	_dirty = true
	emit_signal("global_changed", key, null, old_value)
	emit_signal("state_changed", "global", "", key, null, old_value)
	ATKLog.debug("Global '%s' removed" % key, "ATKState")


func clear_global() -> void:
	if _global.is_empty():
		return
	_global.clear()
	_dirty = true
	ATKLog.debug("Global state cleared.", "ATKState")


func get_scene(scene_id: String, key: String, default_value: Variant = null) -> Variant:
	return _get_scene_dict(scene_id).get(key, default_value)


func has_scene(scene_id: String, key: String) -> bool:
	return _get_scene_dict(scene_id).has(key)


func set_scene(scene_id: String, key: String, value: Variant) -> void:
	var dict := _get_scene_dict(scene_id)
	var old_value: Variant = dict.get(key, null)
	dict[key] = value
	_scene[scene_id] = dict
	_dirty = true
	emit_signal("scene_changed", scene_id, key, value, old_value)
	emit_signal("state_changed", "scene", scene_id, key, value, old_value)
	ATKLog.debug("Scene '%s' '%s' = %s" % [scene_id, key, str(value)], "ATKState")


func remove_scene(scene_id: String, key: String) -> void:
	var dict := _get_scene_dict(scene_id)
	if not dict.has(key):
		return
	var old_value: Variant = dict[key]
	dict.erase(key)
	_scene[scene_id] = dict
	_dirty = true
	emit_signal("scene_changed", scene_id, key, null, old_value)
	emit_signal("state_changed", "scene", scene_id, key, null, old_value)
	ATKLog.debug("Scene '%s' '%s' removed" % [scene_id, key], "ATKState")


func clear_scene(scene_id: String) -> void:
	if scene_id.is_empty():
		return
	if not _scene.has(scene_id):
		return
	_scene.erase(scene_id)
	_dirty = true
	ATKLog.debug("Scene '%s' state cleared." % scene_id, "ATKState")


func clear_all_scenes() -> void:
	if _scene.is_empty():
		return
	_scene.clear()
	_dirty = true
	ATKLog.debug("All scene state cleared.", "ATKState")


func get_current_scene(key: String, default_value: Variant = null) -> Variant:
	var scene_id := _get_current_scene_id()
	if scene_id.is_empty():
		return default_value
	return get_scene(scene_id, key, default_value)


func set_current_scene(key: String, value: Variant) -> void:
	var scene_id := _get_current_scene_id()
	if scene_id.is_empty():
		ATKLog.warn("Cannot set scene state without a current scene_id.", "ATKState")
		return
	set_scene(scene_id, key, value)


func get_object(object_id: String, key: String, default_value: Variant = null) -> Variant:
	return _get_object_dict(object_id).get(key, default_value)


func has_object(object_id: String, key: String) -> bool:
	return _get_object_dict(object_id).has(key)


func set_object(object_id: String, key: String, value: Variant) -> void:
	var dict := _get_object_dict(object_id)
	var old_value: Variant = dict.get(key, null)
	dict[key] = value
	_object[object_id] = dict
	_dirty = true
	emit_signal("object_changed", object_id, key, value, old_value)
	emit_signal("state_changed", "object", object_id, key, value, old_value)
	ATKLog.debug("Object '%s' '%s' = %s" % [object_id, key, str(value)], "ATKState")


func remove_object(object_id: String, key: String) -> void:
	var dict := _get_object_dict(object_id)
	if not dict.has(key):
		return
	var old_value: Variant = dict[key]
	dict.erase(key)
	_object[object_id] = dict
	_dirty = true
	emit_signal("object_changed", object_id, key, null, old_value)
	emit_signal("state_changed", "object", object_id, key, null, old_value)
	ATKLog.debug("Object '%s' '%s' removed" % [object_id, key], "ATKState")


func clear_object(object_id: String) -> void:
	if object_id.is_empty():
		return
	if not _object.has(object_id):
		return
	_object.erase(object_id)
	_dirty = true
	ATKLog.debug("Object '%s' state cleared." % object_id, "ATKState")


func get_session(key: String, default_value: Variant = null) -> Variant:
	return _session.get(key, default_value)


func set_session(key: String, value: Variant) -> void:
	var old_value: Variant = _session.get(key, null)
	_session[key] = value
	emit_signal("session_changed", key, value, old_value)
	emit_signal("state_changed", "session", "", key, value, old_value)
	ATKLog.debug("Session '%s' = %s" % [key, str(value)], "ATKState")


func remove_session(key: String) -> void:
	if not _session.has(key):
		return
	var old_value: Variant = _session[key]
	_session.erase(key)
	emit_signal("session_changed", key, null, old_value)
	emit_signal("state_changed", "session", "", key, null, old_value)
	ATKLog.debug("Session '%s' removed" % key, "ATKState")


func export_state() -> Dictionary:
	return {
		"global": _global.duplicate(true),
		"scene": _scene.duplicate(true),
		"object": _object.duplicate(true),
		"session": _session.duplicate(true),
	}


func import_state(payload: Dictionary) -> void:
	_global = payload.get("global", {}).duplicate(true)
	_scene = payload.get("scene", {}).duplicate(true)
	_object = payload.get("object", {}).duplicate(true)
	_session = payload.get("session", {}).duplicate(true)
	_dirty = false
	ATKLog.info("State imported.", "ATKState")


func _get_scene_dict(scene_id: String) -> Dictionary:
	if scene_id.is_empty():
		return {}
	return _scene.get(scene_id, {}).duplicate(true)


func _get_object_dict(object_id: String) -> Dictionary:
	if object_id.is_empty():
		return {}
	return _object.get(object_id, {}).duplicate(true)


func _get_current_scene_id() -> String:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null:
		return ""
	return scenes.current_scene_id

