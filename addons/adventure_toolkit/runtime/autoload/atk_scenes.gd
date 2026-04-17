extends Node


signal scene_transition_started(scene_id: String, scene_path: String, spawn_id: String)
signal scene_transition_finished(scene_id: String, scene_path: String, spawn_id: String)


var scene_registry: Dictionary = {}
var current_scene_id := ""
var current_scene_path := ""
var current_spawn_id := ""
var pending_spawn_id := ""


func _ready() -> void:
	_refresh_current_scene_tracking()


func register_scene(scene_id: String, scene_path: String) -> void:
	if scene_id.is_empty() or scene_path.is_empty():
		ATKLog.warn("Ignoring scene registration with an empty ID or path.", "ATKScenes")
		return

	scene_registry[scene_id] = scene_path
	ATKLog.debug("Registered scene '%s' -> %s" % [scene_id, scene_path], "ATKScenes")


func unregister_scene(scene_id: String) -> void:
	if scene_registry.erase(scene_id):
		ATKLog.debug("Unregistered scene '%s'." % scene_id, "ATKScenes")


func has_scene(scene_id: String) -> bool:
	return scene_registry.has(scene_id)


func get_registered_scene_path(scene_id: String) -> String:
	return scene_registry.get(scene_id, "")


func load_scene(scene_ref: String, target_spawn_id: String = "", on_finished: Callable = Callable()) -> Error:
	var scene_path := resolve_scene_path(scene_ref)
	if scene_path.is_empty():
		ATKLog.error("Cannot load scene '%s'. No registered path was found." % scene_ref, "ATKScenes")
		return ERR_DOES_NOT_EXIST

	var packed_scene := load(scene_path)
	if packed_scene == null:
		ATKLog.error("Failed to load packed scene at '%s'." % scene_path, "ATKScenes")
		return ERR_CANT_OPEN

	var tree := get_tree()
	if tree == null:
		ATKLog.error("SceneTree is not available.", "ATKScenes")
		return ERR_UNCONFIGURED

	pending_spawn_id = target_spawn_id
	current_spawn_id = target_spawn_id
	var resolved_scene_id := _resolve_scene_id_for_transition(scene_ref, scene_path)
	current_scene_id = resolved_scene_id
	current_scene_path = scene_path
	emit_signal("scene_transition_started", resolved_scene_id, scene_path, pending_spawn_id)
	ATKLog.info("Loading scene '%s' (%s) with spawn '%s'." % [resolved_scene_id, scene_path, pending_spawn_id], "ATKScenes")

	tree.change_scene_to_packed(packed_scene)
	await tree.process_frame

	_refresh_current_scene_tracking(resolved_scene_id, scene_path)
	emit_signal("scene_transition_finished", current_scene_id, current_scene_path, current_spawn_id)
	ATKLog.info("Scene transition finished for '%s'." % current_scene_id, "ATKScenes")

	if on_finished.is_valid():
		on_finished.call(current_scene_id, current_scene_path, current_spawn_id)

	return OK


func resolve_scene_path(scene_ref: String) -> String:
	if scene_ref.begins_with("res://"):
		return scene_ref

	return get_registered_scene_path(scene_ref)


func get_current_scene_root() -> ATKSceneRoot:
	var tree := get_tree()
	if tree == null:
		return null

	var current_scene := tree.current_scene
	if current_scene == null:
		return null

	if current_scene is ATKSceneRoot:
		return current_scene as ATKSceneRoot

	for child in current_scene.find_children("*", "ATKSceneRoot", true, false):
		return child as ATKSceneRoot

	return null


func get_current_spawn_point() -> ATKSpawnPoint:
	if current_spawn_id.is_empty():
		return null

	return get_spawn_point_by_id(current_spawn_id)


func get_spawn_point_by_id(spawn_id: String) -> ATKSpawnPoint:
	var scene_root := get_current_scene_root()
	if scene_root == null:
		return null

	for child in scene_root.find_children("*", "ATKSpawnPoint", true, false):
		if child.spawn_id == spawn_id:
			return child as ATKSpawnPoint

	return null


func set_current_spawn_id(spawn_id: String) -> void:
	current_spawn_id = spawn_id


func _refresh_current_scene_tracking(fallback_scene_id: String = "", fallback_scene_path: String = "") -> void:
	var scene_root := get_current_scene_root()
	if scene_root == null:
		if not fallback_scene_id.is_empty():
			current_scene_id = fallback_scene_id
		if not fallback_scene_path.is_empty():
			current_scene_path = fallback_scene_path
		current_spawn_id = pending_spawn_id
		return

	current_scene_id = scene_root.scene_id
	current_scene_path = scene_root.scene_file_path
	if not current_scene_id.is_empty() and not current_scene_path.is_empty():
		register_scene(current_scene_id, current_scene_path)

	if not pending_spawn_id.is_empty():
		current_spawn_id = pending_spawn_id
	pending_spawn_id = ""


func _resolve_scene_id_for_transition(scene_ref: String, scene_path: String) -> String:
	if scene_registry.has(scene_ref):
		return scene_ref

	for registered_scene_id in scene_registry.keys():
		if scene_registry[registered_scene_id] == scene_path:
			return registered_scene_id

	return scene_ref.get_file().get_basename()
