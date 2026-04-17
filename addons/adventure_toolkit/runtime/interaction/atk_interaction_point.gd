@tool
class_name ATKInteractionPoint
extends Marker3D


@export var interaction_id := ""
@export var approach_offset := Vector3.ZERO
@export var facing_target_path: NodePath


func _get_configuration_warnings() -> PackedStringArray:
	return validate_configuration()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if interaction_id.is_empty():
		issues.append("ATKInteractionPoint should have a stable interaction_id.")
	return issues


func get_approach_position() -> Vector3:
	return global_position + approach_offset


func get_facing_target() -> Node3D:
	if facing_target_path.is_empty():
		return null

	var target := get_node_or_null(facing_target_path)
	if target is Node3D:
		return target as Node3D

	return null
