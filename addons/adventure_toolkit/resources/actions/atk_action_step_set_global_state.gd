@tool
class_name ATKActionStepSetGlobalState
extends ATKActionStep

@export var state_key := ""
@export var value: Variant


func run(_context: ATKActionContext) -> void:
	if state_key.is_empty():
		ATKLog.warn("Set-global step '%s' has empty state_key." % _debug_name(), "ATKAction")
		return
	var state := _get_state()
	if state == null:
		ATKLog.warn("ATKState missing for set-global step '%s'." % _debug_name(), "ATKAction")
		return
	state.set_global(state_key, value)
	ATKLog.debug("Set global '%s'." % state_key, "ATKAction")


func _get_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")
