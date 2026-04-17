class_name ATKDoor
extends ATKAdventureObject

## Shared adventure door logic (Phase 9). Interaction order matches the toolkit plan:
## disabled -> jammed -> locked (item / global / scene / other-object gates) -> open -> optional scene change.


enum DoorTransitionMode {
	NONE,
	CHANGE_SCENE_ON_OPEN,
}


const STATE_KEY_LOCKED := "door_locked"
const STATE_KEY_OPEN := "door_open"
const STATE_KEY_JAMMED := "door_jammed"


@export var is_locked := true
@export var is_open := false
@export var is_jammed := false

@export var required_item_id := ""
@export var consume_item_on_unlock := false

@export var required_global_key := ""
@export var required_global_value: Variant
@export var require_global_exact := true

@export var required_scene_state_key := ""
@export var required_scene_state_value: Variant
@export var require_scene_state_exact := true

@export var required_other_object_id := ""
@export var required_other_object_key := ""
@export var required_other_object_value: Variant
@export var require_other_object_exact := true

@export var unlock_sequence: ATKActionSequence
@export var open_sequence: ATKActionSequence

@export_multiline var locked_response := "It's locked."
@export_multiline var wrong_item_response := "That doesn't work here."
@export_multiline var jammed_response := "This door won't budge."
@export_multiline var already_open_response := "The door is already open."

@export var destination_scene_id := ""
@export var destination_spawn_id := ""
@export var door_transition_mode: DoorTransitionMode = DoorTransitionMode.NONE

## Shown as the second hover line when [member is_open] is true (if [member ATKAdventureObject.hover_tooltip_secondary] is empty).
@export_multiline var hover_tooltip_when_open := ""


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_load_door_state_from_storage()


func _validate_property(property: Dictionary) -> void:
	var prop_name := str(property.get("name", ""))
	if prop_name == "required_item_id":
		var item_ids := _collect_inventory_item_ids()
		if not item_ids.is_empty():
			property["hint"] = PROPERTY_HINT_ENUM
			property["hint_string"] = ",".join(item_ids)
		return
	if prop_name == "destination_spawn_id":
		var spawn_ids := _collect_spawn_ids_from_current_scene()
		if not spawn_ids.is_empty():
			property["hint"] = PROPERTY_HINT_ENUM
			property["hint_string"] = ",".join(spawn_ids)
		return


func validate_configuration() -> PackedStringArray:
	var issues := super.validate_configuration()
	if door_transition_mode == DoorTransitionMode.CHANGE_SCENE_ON_OPEN and destination_scene_id.is_empty():
		issues.append("ATKDoor: CHANGE_SCENE_ON_OPEN requires destination_scene_id.")
	return issues


func interact_default(actor: Node) -> void:
	if not can_interact():
		return
	if _resolve_active_verb(actor) == "inspect":
		await super.interact_default(actor)
		return

	var action_ctx := _build_action_context(actor, _resolve_active_verb(actor))
	var was_open := is_open

	if is_jammed:
		_push_interaction_message(_response_or_default(jammed_response, "This door is jammed."))
		await _run_optional_sequence(null, action_ctx)
		_increment_interaction_count()
		return

	if is_open and not is_locked:
		_push_interaction_message(_response_or_default(already_open_response, "The door is already open."))
		await _run_optional_sequence(null, action_ctx)
		_increment_interaction_count()
		return

	if is_locked:
		if not _unlock_requirements_met(action_ctx):
			if _should_wrong_item_feedback(action_ctx):
				_push_interaction_message(_response_or_default(wrong_item_response, "That doesn't work."))
			else:
				_push_interaction_message(_response_or_default(locked_response, "It's locked."))
			_increment_interaction_count()
			return

		if not required_item_id.is_empty() and consume_item_on_unlock:
			var inv := _get_inventory()
			if inv != null and inv.has_method("remove_item"):
				inv.remove_item(required_item_id, 1)

		await _run_optional_sequence(unlock_sequence, action_ctx)
		_set_locked(false)

	if not is_open:
		await _run_optional_sequence(open_sequence, action_ctx)
		_set_open(true)

	if (
		door_transition_mode == DoorTransitionMode.CHANGE_SCENE_ON_OPEN
		and not was_open
		and is_open
		and not destination_scene_id.is_empty()
	):
		var scenes := get_node_or_null("/root/ATKScenes")
		if scenes != null and scenes.has_method("load_scene"):
			ATKLog.info("Door '%s' transitioning to '%s'." % [object_id, destination_scene_id], "ATKDoor")
			await scenes.load_scene(destination_scene_id, destination_spawn_id)
		else:
			ATKLog.error("ATKScenes missing; cannot transition door '%s'." % object_id, "ATKDoor")

	_increment_interaction_count()


func _load_door_state_from_storage() -> void:
	if object_id.is_empty():
		return
	var state := _get_state_manager()
	if state == null:
		return

	is_locked = bool(state.get_object(object_id, STATE_KEY_LOCKED, is_locked))
	is_open = bool(state.get_object(object_id, STATE_KEY_OPEN, is_open))
	is_jammed = bool(state.get_object(object_id, STATE_KEY_JAMMED, is_jammed))

	state.set_object(object_id, STATE_KEY_LOCKED, is_locked)
	state.set_object(object_id, STATE_KEY_OPEN, is_open)
	state.set_object(object_id, STATE_KEY_JAMMED, is_jammed)


func _set_locked(value: bool) -> void:
	var old := is_locked
	is_locked = value
	_emit_runtime_state_changed(STATE_KEY_LOCKED, value, old)
	_persist_runtime_state_value(STATE_KEY_LOCKED, value)


func _set_open(value: bool) -> void:
	var old := is_open
	is_open = value
	_emit_runtime_state_changed(STATE_KEY_OPEN, value, old)
	_persist_runtime_state_value(STATE_KEY_OPEN, value)


func _unlock_requirements_met(ctx: ATKActionContext) -> bool:
	if not required_item_id.is_empty():
		var inv := _get_inventory()
		if inv == null or not inv.has_method("has_item"):
			return false
		if not bool(inv.call("has_item", required_item_id, 1)):
			return false
		var selected := ctx.selected_item_id
		if not selected.is_empty() and selected != required_item_id:
			return false

	if not required_global_key.is_empty():
		var st := _get_state_manager()
		if st == null:
			return false
		if require_global_exact:
			if st.get_global(required_global_key, null) != required_global_value:
				return false
		else:
			if not st.has_global(required_global_key):
				return false

	if not required_scene_state_key.is_empty():
		var st2 := _get_state_manager()
		if st2 == null:
			return false
		var sid := ctx.scene_id
		if sid.is_empty():
			sid = _get_current_scene_id()
		if require_scene_state_exact:
			if st2.get_scene(sid, required_scene_state_key, null) != required_scene_state_value:
				return false
		else:
			if not st2.has_scene(sid, required_scene_state_key):
				return false

	if not required_other_object_id.is_empty() and not required_other_object_key.is_empty():
		var st3 := _get_state_manager()
		if st3 == null:
			return false
		if require_other_object_exact:
			if st3.get_object(required_other_object_id, required_other_object_key, null) != required_other_object_value:
				return false
		else:
			if not st3.has_object(required_other_object_id, required_other_object_key):
				return false

	return true


func _should_wrong_item_feedback(ctx: ATKActionContext) -> bool:
	if required_item_id.is_empty():
		return false
	var selected := ctx.selected_item_id
	return not selected.is_empty() and selected != required_item_id


func _get_inventory() -> Node:
	return get_node_or_null("/root/ATKInventory")


func _run_optional_sequence(sequence: ATKActionSequence, ctx: ATKActionContext) -> void:
	if sequence == null or sequence.steps.is_empty():
		return
	await ATKActionRunner.run_sequence(sequence, ctx, Callable())


func _response_or_default(text: String, default_text: String) -> String:
	var t := text.strip_edges()
	return t if not t.is_empty() else default_text


func get_hover_tooltip_secondary() -> String:
	var base := super.get_hover_tooltip_secondary().strip_edges()
	if not base.is_empty():
		return base
	if is_open:
		return hover_tooltip_when_open.strip_edges()
	return ""


func _collect_inventory_item_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	_collect_inventory_item_ids_in_dir("res://addons/adventure_toolkit/resources/inventory/items", ids)
	ids.sort()
	return ids


func _collect_inventory_item_ids_in_dir(path: String, out_ids: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect_inventory_item_ids_in_dir("%s/%s" % [path, sub], out_ids)
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var full_path := "%s/%s" % [path, file_name]
		var res := load(full_path)
		if not (res is ATKInventoryItemDefinition):
			continue
		var item := (res as ATKInventoryItemDefinition).item_id.strip_edges()
		if item.is_empty():
			continue
		if not out_ids.has(item):
			out_ids.append(item)


func _collect_spawn_ids_from_current_scene() -> PackedStringArray:
	var ids := PackedStringArray()
	var tree := get_tree()
	if tree == null:
		return ids
	var root := tree.edited_scene_root if Engine.is_editor_hint() else tree.current_scene
	if root == null:
		return ids
	for child in root.find_children("*", "ATKSpawnPoint", true, false):
		var spawn_id := str(child.spawn_id).strip_edges()
		if spawn_id.is_empty():
			continue
		if not ids.has(spawn_id):
			ids.append(spawn_id)
	ids.sort()
	return ids
