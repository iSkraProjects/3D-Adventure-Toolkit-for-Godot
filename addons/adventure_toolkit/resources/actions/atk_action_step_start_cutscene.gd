@tool
class_name ATKActionStepStartCutscene
extends ATKActionStep

## Phase 18.1: action hook to request cutscene playback via ATKCutscenes.

@export var cutscene_id := ""
@export var await_completion := false
@export var on_skipped_resolution: ATKActionSequence


func run(context: ATKActionContext) -> void:
	var id := cutscene_id.strip_edges()
	if id.is_empty():
		ATKLog.warn("Start-cutscene step '%s' has empty cutscene_id." % _debug_name(), "ATKAction")
		return

	var cutscenes := _get_cutscenes()
	if cutscenes == null:
		ATKLog.warn("ATKCutscenes missing for start-cutscene step '%s'." % _debug_name(), "ATKAction")
		return

	var ctx := {
		"actor_path": context.actor.get_path() if context.actor != null else NodePath(),
		"target_path": context.target.get_path() if context.target != null else NodePath(),
		"scene_id": context.scene_id,
		"object_id": context.object_id,
		"verb": context.verb,
	}
	var ok: bool = await cutscenes.request_cutscene(id, ctx, await_completion)
	if not ok:
		ATKLog.warn("Start-cutscene step '%s' failed for '%s'." % [_debug_name(), id], "ATKAction")
		return

	if await_completion and on_skipped_resolution != null:
		var result := ""
		if cutscenes.has_method("get_last_resolution"):
			result = str(cutscenes.call("get_last_resolution", id))
		if result == "skipped":
			ATKLog.debug("Applying skip-safe resolution for cutscene '%s'." % id, "ATKAction")
			await ATKActionRunner.run_sequence(on_skipped_resolution, context, Callable())


func _get_cutscenes() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKCutscenes")
