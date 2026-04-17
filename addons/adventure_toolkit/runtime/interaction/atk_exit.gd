class_name ATKExit
extends ATKAdventureObject

## No-code scene exit object for designers.

@export_file("*.tscn") var destination_scene_path := ""
@export var destination_scene_id := ""
@export var destination_spawn_id := ""
@export var require_enabled_to_exit := true
@export_multiline var blocked_response := "You can't go there right now."


func interact_default(actor: Node) -> void:
	if not can_interact():
		return
	if _resolve_active_verb(actor) == "inspect":
		await super.interact_default(actor)
		return
	if require_enabled_to_exit and not is_enabled:
		var msg := blocked_response.strip_edges()
		if not msg.is_empty():
			_push_interaction_message(msg)
		_increment_interaction_count()
		return

	var scene_ref := destination_scene_id.strip_edges()
	if scene_ref.is_empty():
		scene_ref = destination_scene_path.strip_edges()
	if scene_ref.is_empty():
		ATKLog.warn("ATKExit '%s' has no destination scene." % object_id, "ATKExit")
		await super.interact_default(actor)
		return

	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null or not scenes.has_method("load_scene"):
		ATKLog.warn("ATKExit '%s' cannot load destination: ATKScenes missing." % object_id, "ATKExit")
		return
	var err: Error = await scenes.load_scene(scene_ref, destination_spawn_id.strip_edges())
	if err != OK:
		ATKLog.error("ATKExit '%s' failed to load '%s' (%d)." % [object_id, scene_ref, err], "ATKExit")
	_increment_interaction_count()
