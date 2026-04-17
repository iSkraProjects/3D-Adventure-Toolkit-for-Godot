@tool
class_name ATKActionStepSetSceneState
extends ATKActionStep

@export var scene_id := ""
@export var state_key := ""
@export var value: Variant


func run(context: ATKActionContext) -> void:
	if state_key.is_empty():
		ATKLog.warn("Set-scene step '%s' has empty state_key." % _debug_name(), "ATKAction")
		return
	var state := _get_state()
	if state == null:
		ATKLog.warn("ATKState missing for set-scene step '%s'." % _debug_name(), "ATKAction")
		return

	var sid := scene_id.strip_edges()
	if sid.is_empty():
		sid = context.scene_id.strip_edges()
	if sid.is_empty():
		var scenes := _get_scenes()
		if scenes != null:
			sid = str(scenes.current_scene_id)

	if sid.is_empty():
		ATKLog.warn("Set-scene step '%s' could not resolve scene_id." % _debug_name(), "ATKAction")
		return

	state.set_scene(sid, state_key, value)
	ATKLog.debug("Set scene '%s' key '%s'." % [sid, state_key], "ATKAction")


func _get_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")


func _get_scenes() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKScenes")
