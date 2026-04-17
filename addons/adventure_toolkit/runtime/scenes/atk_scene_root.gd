@tool
class_name ATKSceneRoot
extends Node3D


@export var scene_id := ""
@export var scene_label := ""
@export var metadata: Dictionary = {}
@export var is_toolkit_scene := true
## Optional layered hints for this scene (Phase 16). Registered and set on [ATKHints] at runtime.
@export var scene_hint_bank: ATKHintBank
## Optional scene-level looping music and ambience hooks (Phase 17.2).
@export var music_stream: AudioStream
@export var ambience_stream: AudioStream
## Optional scripted sequence triggered on scene load (Phase 18.3).
@export var on_scene_load_actions: ATKActionSequence
@export var run_scene_load_actions_once := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_apply_requested_spawn()
	call_deferred("_apply_scene_hint_bank")
	call_deferred("_run_scene_load_actions_if_configured")


func _get_configuration_warnings() -> PackedStringArray:
	return validate_configuration()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if scene_id.is_empty():
		issues.append("ATKSceneRoot requires a stable scene_id.")
	if not is_toolkit_scene:
		issues.append("ATKSceneRoot should remain marked as a toolkit scene root.")
	return issues


func has_metadata_value(key: StringName) -> bool:
	return metadata.has(key)


func get_metadata_value(key: StringName, default_value: Variant = null) -> Variant:
	if metadata.has(key):
		return metadata[key]
	return default_value


func get_music_stream() -> AudioStream:
	return music_stream


func get_ambience_stream() -> AudioStream:
	return ambience_stream


func _apply_scene_hint_bank() -> void:
	var hints := get_node_or_null("/root/ATKHints")
	if hints == null or scene_hint_bank == null:
		return
	if hints.has_method("register_hint_bank"):
		hints.register_hint_bank(scene_hint_bank)
	var bid := scene_hint_bank.hint_bank_id.strip_edges()
	if bid.is_empty():
		return
	if hints.has_method("set_scene_hint_bank"):
		hints.set_scene_hint_bank(bid)


func get_spawn_point(spawn_id: String) -> ATKSpawnPoint:
	for child in find_children("*", "ATKSpawnPoint", true, false):
		if child.spawn_id == spawn_id:
			return child as ATKSpawnPoint

	return null


func _apply_requested_spawn() -> void:
	var scene_manager := get_node_or_null("/root/ATKScenes")
	if scene_manager == null:
		return

	var requested_spawn_id: String = scene_manager.current_spawn_id
	if requested_spawn_id.is_empty():
		return

	var spawn_point := get_spawn_point(requested_spawn_id)
	if spawn_point == null:
		return

	for child in find_children("*", "Node3D", true, false):
		if child.is_in_group("atk_player_start"):
			child.global_transform = spawn_point.global_transform
			break


func _run_scene_load_actions_if_configured() -> void:
	if on_scene_load_actions == null or on_scene_load_actions.steps.is_empty():
		return
	if run_scene_load_actions_once and _has_run_scene_load_actions():
		return

	var ctx := ATKActionContext.new()
	ctx.scene_id = scene_id
	var actor := _find_player_actor()
	ctx.actor = actor
	ctx.target = self
	ctx.object_id = scene_id
	ctx.verb = "scene_load"

	ATKLog.info("Running scene-load actions for '%s'." % scene_id, "ATKSceneRoot")
	await ATKActionRunner.run_sequence(on_scene_load_actions, ctx, Callable())
	if run_scene_load_actions_once:
		_mark_scene_load_actions_ran()


func _has_run_scene_load_actions() -> bool:
	var state := get_node_or_null("/root/ATKState")
	if state == null:
		return false
	var key := _scene_load_actions_key()
	return bool(state.get_scene(scene_id, key, false))


func _mark_scene_load_actions_ran() -> void:
	var state := get_node_or_null("/root/ATKState")
	if state == null:
		return
	state.set_scene(scene_id, _scene_load_actions_key(), true)


func _scene_load_actions_key() -> String:
	return "_scene_load_actions_ran"


func _find_player_actor() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("atk_player"):
		return n as Node
	return null
