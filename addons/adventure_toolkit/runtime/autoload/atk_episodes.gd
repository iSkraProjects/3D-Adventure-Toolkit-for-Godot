extends Node

## Phase 23: episode metadata + carryover import/export.

signal active_episode_changed(episode_id: String)

var _episodes: Dictionary = {} # episode_id -> ATKEpisodeDefinition
var _active_episode_id := ""


func register_episode(definition: ATKEpisodeDefinition) -> void:
	if definition == null:
		return
	var id := definition.episode_id.strip_edges()
	if id.is_empty():
		ATKLog.warn("Ignoring episode definition with empty episode_id.", "ATKEpisodes")
		return
	_episodes[id] = definition


func get_episode(episode_id: String) -> ATKEpisodeDefinition:
	return _episodes.get(episode_id.strip_edges(), null)


func list_episode_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _episodes.keys():
		out.append(str(id))
	out.sort()
	return out


func set_active_episode(episode_id: String) -> void:
	var id := episode_id.strip_edges()
	if id == _active_episode_id:
		return
	_active_episode_id = id
	emit_signal("active_episode_changed", _active_episode_id)


func get_active_episode_id() -> String:
	return _active_episode_id


func export_carryover_snapshot(episode_id: String = "") -> Dictionary:
	var target_id := episode_id.strip_edges()
	if target_id.is_empty():
		target_id = _active_episode_id
	var ep := get_episode(target_id)
	if ep == null:
		return {}

	var out := {
		"schema_version": 1,
		"episode_id": target_id,
		"global": {},
		"inventory_items": {},
		"recap_lines": ep.recap_lines.duplicate(),
	}

	var state := get_node_or_null("/root/ATKState")
	if state != null:
		var global_payload := {}
		for key in ep.carryover_global_keys:
			var k := key.strip_edges()
			if k.is_empty():
				continue
			if state.has_global(k):
				global_payload[k] = state.get_global(k, null)
		out["global"] = global_payload

	var inv := get_node_or_null("/root/ATKInventory")
	if inv != null:
		var item_payload := {}
		for item_id in ep.carryover_inventory_item_ids:
			var id := item_id.strip_edges()
			if id.is_empty():
				continue
			if inv.has_item(id):
				item_payload[id] = 1
		out["inventory_items"] = item_payload
	return out


func apply_carryover_snapshot(snapshot: Dictionary, target_episode_id: String = "") -> bool:
	if snapshot.is_empty():
		return false
	var episode_id := target_episode_id.strip_edges()
	if episode_id.is_empty():
		episode_id = str(snapshot.get("episode_id", "")).strip_edges()
	if episode_id.is_empty():
		return false

	var ep := get_episode(episode_id)
	if ep == null:
		return false

	var state := get_node_or_null("/root/ATKState")
	if state != null:
		var g := snapshot.get("global", {})
		if g is Dictionary:
			for key in (g as Dictionary).keys():
				state.set_global(str(key), g[key])

	var inv := get_node_or_null("/root/ATKInventory")
	if inv != null:
		var items := snapshot.get("inventory_items", {})
		if items is Dictionary:
			for item_id in (items as Dictionary).keys():
				inv.add_item(str(item_id), int(items[item_id]))

	set_active_episode(episode_id)
	return true


func start_episode(episode_id: String) -> bool:
	var ep := get_episode(episode_id)
	if ep == null:
		return false
	set_active_episode(ep.episode_id)
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null or not scenes.has_method("load_scene"):
		return false
	var err: Error = await scenes.load_scene(ep.start_scene_id, ep.start_spawn_id)
	return err == OK
