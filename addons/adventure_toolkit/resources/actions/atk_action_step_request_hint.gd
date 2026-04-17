@tool
class_name ATKActionStepRequestHint
extends ATKActionStep

## Triggers [method ATKHints.request_next_hint] (same as the hint HUD button).


func run(_context: ATKActionContext) -> void:
	var hints := _get_hints()
	if hints == null or not hints.has_method("request_next_hint"):
		ATKLog.warn("Request-hint step '%s': ATKHints missing." % _debug_name(), "ATKAction")
		return
	hints.call("request_next_hint")


func _get_hints() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKHints")
