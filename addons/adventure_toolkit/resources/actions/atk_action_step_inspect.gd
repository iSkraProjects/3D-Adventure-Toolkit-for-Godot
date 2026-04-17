@tool
class_name ATKActionStepInspect
extends ATKActionStep

@export_multiline var text := ""


func run(context: ATKActionContext) -> void:
	var line := text.strip_edges()
	if line.is_empty():
		ATKLog.warn("Inspect step '%s' has empty text." % _debug_name(), "ATKAction")
		return
	ATKLog.info(line, "ATKInteraction")
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var bus: Node = tree.root.get_node_or_null("ATKInteractionFeedback")
	if bus != null and bus.has_method("show_message"):
		var title := ""
		if context.target is Node:
			title = (context.target as Node).name
		bus.show_message(line, title, context.object_id)
