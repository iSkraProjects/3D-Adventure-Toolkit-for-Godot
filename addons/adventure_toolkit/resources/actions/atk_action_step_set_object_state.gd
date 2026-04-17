@tool
class_name ATKActionStepSetObjectState
extends ATKActionStep

@export var object_id := ""
@export var state_key := ""
@export var value: Variant


func run(context: ATKActionContext) -> void:
	if state_key.is_empty():
		ATKLog.warn("Set-object step '%s' has empty state_key." % _debug_name(), "ATKAction")
		return
	var state := _get_state()
	if state == null:
		ATKLog.warn("ATKState missing for set-object step '%s'." % _debug_name(), "ATKAction")
		return

	var oid := object_id.strip_edges()
	if oid.is_empty():
		oid = context.object_id.strip_edges()
	if oid.is_empty():
		ATKLog.warn("Set-object step '%s' could not resolve object_id." % _debug_name(), "ATKAction")
		return

	state.set_object(oid, state_key, value)
	ATKLog.debug("Set object '%s' key '%s'." % [oid, state_key], "ATKAction")


func _get_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")
