@tool
class_name ATKActionStepWait
extends ATKActionStep

@export var wait_seconds := 0.0


func run(context: ATKActionContext) -> void:
	var duration := maxf(wait_seconds, 0.0)
	if duration <= 0.0:
		return
	var tree := _resolve_tree(context)
	if tree == null:
		ATKLog.warn("Wait step '%s' could not resolve SceneTree." % _debug_name(), "ATKAction")
		return
	ATKLog.debug("Wait %fs" % duration, "ATKAction")
	await tree.create_timer(duration).timeout


func _resolve_tree(context: ATKActionContext) -> SceneTree:
	if context.actor != null:
		return context.actor.get_tree()
	return Engine.get_main_loop() as SceneTree
