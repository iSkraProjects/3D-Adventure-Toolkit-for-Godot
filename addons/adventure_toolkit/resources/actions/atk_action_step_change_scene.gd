@tool
class_name ATKActionStepChangeScene
extends ATKActionStep

@export var scene_id := ""
@export var spawn_id := ""


func run(_context: ATKActionContext) -> void:
	if scene_id.is_empty():
		ATKLog.warn("Change-scene step '%s' has empty scene_id." % _debug_name(), "ATKAction")
		return
	var scenes := _get_scenes()
	if scenes == null:
		ATKLog.warn("ATKScenes missing for change-scene step '%s'." % _debug_name(), "ATKAction")
		return
	ATKLog.info("Change scene -> '%s' spawn '%s'." % [scene_id, spawn_id], "ATKAction")
	var err: Error = await scenes.load_scene(scene_id, spawn_id)
	if err != OK:
		ATKLog.error("Change-scene step '%s' failed (%d)." % [_debug_name(), err], "ATKAction")


func _get_scenes() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKScenes")
