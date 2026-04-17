@tool
class_name ATKSpawnPoint
extends Marker3D


@export var spawn_id := ""


func _get_configuration_warnings() -> PackedStringArray:
	return validate_configuration()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if spawn_id.is_empty():
		issues.append("ATKSpawnPoint requires a stable spawn_id.")

	var scene_root := get_parent_scene_root()
	if scene_root == null:
		issues.append("ATKSpawnPoint should live under an ATKSceneRoot scene.")
		return issues

	if _has_duplicate_spawn_id(scene_root):
		issues.append("Another ATKSpawnPoint in this scene already uses spawn_id '%s'." % spawn_id)

	return issues


func get_parent_scene_root() -> ATKSceneRoot:
	var current: Node = get_parent()
	while current != null:
		if current is ATKSceneRoot:
			return current as ATKSceneRoot
		current = current.get_parent()
	return null


func _has_duplicate_spawn_id(scene_root: ATKSceneRoot) -> bool:
	if spawn_id.is_empty():
		return false

	for child in scene_root.find_children("*", "ATKSpawnPoint", true, false):
		if child == self:
			continue
		if child.spawn_id == spawn_id:
			return true

	return false
