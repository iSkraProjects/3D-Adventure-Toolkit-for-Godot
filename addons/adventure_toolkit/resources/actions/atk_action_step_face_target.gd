@tool
class_name ATKActionStepFaceTarget
extends ATKActionStep

## If empty, uses context.target when it is Node3D.


@export var target_path: NodePath


func run(context: ATKActionContext) -> void:
	var actor3 := context.actor as Node3D
	if actor3 == null:
		ATKLog.warn("Face-target step '%s' needs a Node3D actor." % _debug_name(), "ATKAction")
		return

	var target := _resolve_target(context)
	if target == null:
		ATKLog.warn("Face-target step '%s' could not resolve target." % _debug_name(), "ATKAction")
		return

	var look := Vector3(target.global_position.x, actor3.global_position.y, target.global_position.z)
	actor3.look_at(look, Vector3.UP)
	ATKLog.debug("Actor faced target '%s'." % target.name, "ATKAction")


func _resolve_target(context: ATKActionContext) -> Node3D:
	if not target_path.is_empty() and context.actor != null:
		var n := context.actor.get_node_or_null(target_path)
		if n is Node3D:
			return n as Node3D
	if context.target is Node3D:
		return context.target as Node3D
	return null
