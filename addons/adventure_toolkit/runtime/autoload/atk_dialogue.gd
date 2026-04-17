extends Node

## Data-driven dialogue runtime (Phase 10). UI listens to signals and calls
## `submit_continue()` / `submit_choice(ui_index)` to advance.
##
## Default dialogue UI is parented here so it survives [method SceneTree.change_scene_to_packed],
## which replaces the whole main scene (including any UI placed only in bootstrap).


const _DEFAULT_DIALOGUE_UI := preload("res://addons/adventure_toolkit/ui/runtime/atk_dialogue_ui.tscn")


signal dialogue_started(definition_id: String)
signal line_shown(node_id: String, speaker: String, line_text: String)
signal choices_shown(node_id: String, choice_labels: PackedStringArray)
signal dialogue_finished(definition_id: String)

signal dialogue_continue_requested
signal dialogue_choice_submitted


var _running := false
var _definition: ATKDialogueDefinition
var _actor: Node
var _target: Node
var _ctx: ATKActionContext
var _choice_ui_index := -1


func _ready() -> void:
	var ui := _DEFAULT_DIALOGUE_UI.instantiate()
	ui.name = "DefaultDialogueUI"
	add_child(ui)


func is_active() -> bool:
	return _running


func start_dialogue(
	definition: ATKDialogueDefinition,
	actor: Node,
	dialogue_target: Node = null,
	auto_continue_without_ui := false,
	dialogue_camera: Camera3D = null,
	dialogue_camera_priority: int = 60
) -> void:
	if definition == null or definition.start_node_id.is_empty():
		ATKLog.warn("start_dialogue: invalid definition or empty start_node_id.", "ATKDialogue")
		return
	if _running:
		ATKLog.warn("start_dialogue: dialogue already running.", "ATKDialogue")
		return

	_running = true
	_definition = definition
	_actor = actor
	_target = dialogue_target if dialogue_target != null else actor
	_ctx = _build_action_context()

	var cam_token := -1
	var director: ATKCameraDirector = null
	var tree := get_tree()
	if tree != null:
		director = ATKCameraDirector.find_director(tree)
	if dialogue_camera != null and director != null:
		cam_token = director.request_interaction_camera(dialogue_camera, dialogue_camera_priority)

	var def_id := definition.dialogue_id
	if def_id.is_empty():
		def_id = definition.resource_path.get_file()

	emit_signal("dialogue_started", def_id)

	var id := definition.start_node_id
	while _running and not id.is_empty():
		var node := _find_node(id)
		if node == null:
			ATKLog.warn("Dialogue node '%s' not found." % id, "ATKDialogue")
			break

		if node.entry_conditions != null:
			var gate := ATKConditionEvaluator.evaluate(node.entry_conditions, _eval_context(), false)
			if not bool(gate.get(ATKCondition.RESULT_KEY_PASSED, false)):
				var fb := node.fallback_next_node_id.strip_edges()
				if fb.is_empty():
					ATKLog.debug("Dialogue node '%s' failed entry gate; stopping." % id, "ATKDialogue")
					break
				id = fb
				continue

		if node.on_enter_actions != null and not node.on_enter_actions.steps.is_empty():
			await ATKActionRunner.run_sequence(node.on_enter_actions, _ctx, Callable())

		_play_voice_for_node(node)
		emit_signal("line_shown", node.node_id, node.speaker_name, node.text)
		ATKLog.info("[%s] %s" % [node.speaker_name, node.text.strip_edges()], "ATKDialogue")

		var filtered := _filter_choices(node)
		if filtered.is_empty():
			if auto_continue_without_ui:
				await get_tree().create_timer(0.05).timeout
				if not _running:
					break
			else:
				await dialogue_continue_requested
			if not _running:
				break
			if node.on_leave_actions != null and not node.on_leave_actions.steps.is_empty():
				await ATKActionRunner.run_sequence(node.on_leave_actions, _ctx, Callable())
			if node.ends_dialogue:
				id = ""
			else:
				id = node.next_node_id.strip_edges()
		else:
			var labels := PackedStringArray()
			for ch in filtered:
				labels.append(ch.choice_text)
			emit_signal("choices_shown", node.node_id, labels)
			_choice_ui_index = -1
			await dialogue_choice_submitted
			if not _running:
				break
			var pick := _choice_ui_index
			if pick < 0 or pick >= filtered.size():
				ATKLog.warn("Invalid dialogue choice index %d." % pick, "ATKDialogue")
				break
			var chosen: ATKDialogueChoice = filtered[pick]
			if chosen.on_chosen_actions != null and not chosen.on_chosen_actions.steps.is_empty():
				await ATKActionRunner.run_sequence(chosen.on_chosen_actions, _ctx, Callable())
			id = chosen.target_node_id.strip_edges()

	if cam_token >= 0 and director != null:
		director.release_interaction_camera(cam_token)

	_stop_voice()
	emit_signal("dialogue_finished", def_id)
	_clear_run_state()


func end_dialogue() -> void:
	_running = false
	_stop_voice()
	dialogue_continue_requested.emit()
	dialogue_choice_submitted.emit()


func submit_continue() -> void:
	if _running:
		dialogue_continue_requested.emit()


func submit_choice(ui_index: int) -> void:
	if not _running:
		return
	_choice_ui_index = ui_index
	dialogue_choice_submitted.emit()


func _clear_run_state() -> void:
	_running = false
	_definition = null
	_actor = null
	_target = null
	_ctx = null
	_choice_ui_index = -1


func _find_node(node_id: String) -> ATKDialogueNode:
	if _definition == null:
		return null
	for n in _definition.nodes:
		if n != null and n.node_id == node_id:
			return n
	return null


func _filter_choices(node: ATKDialogueNode) -> Array[ATKDialogueChoice]:
	var out: Array[ATKDialogueChoice] = []
	for ch in node.choices:
		if ch == null:
			continue
		if ch.conditions != null:
			var res := ATKConditionEvaluator.evaluate(ch.conditions, _eval_context(), false)
			if not bool(res.get(ATKCondition.RESULT_KEY_PASSED, false)):
				continue
		out.append(ch)
	return out


func _eval_context() -> Dictionary:
	var ctx := {
		"actor": _actor,
		"scene_id": _scene_id(),
	}
	var state := get_node_or_null("/root/ATKState")
	if state != null:
		ctx["state"] = state
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory != null:
		ctx["inventory"] = inventory
		if inventory.has_method("get_selected_item"):
			ctx["selected_item_id"] = str(inventory.call("get_selected_item"))
	var quests := get_node_or_null("/root/ATKQuests")
	if quests != null:
		ctx["quests"] = quests
	if _target is ATKAdventureObject:
		ctx["object_id"] = (_target as ATKAdventureObject).object_id
	return ctx


func _scene_id() -> String:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null:
		return ""
	return str(scenes.current_scene_id)


func _build_action_context() -> ATKActionContext:
	var c := ATKActionContext.new()
	c.actor = _actor
	c.target = _target
	c.scene_id = _scene_id()
	c.verb = "dialogue"
	if _target is ATKAdventureObject:
		c.object_id = (_target as ATKAdventureObject).object_id
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory != null and inventory.has_method("get_selected_item"):
		c.selected_item_id = str(inventory.call("get_selected_item"))
	return c


func _play_voice_for_node(node: ATKDialogueNode) -> void:
	var audio := get_node_or_null("/root/ATKAudio")
	if audio == null or not audio.has_method("play_dialogue_voice"):
		return
	audio.call("play_dialogue_voice", node.voice_stream)


func _stop_voice() -> void:
	var audio := get_node_or_null("/root/ATKAudio")
	if audio == null or not audio.has_method("stop_dialogue_voice"):
		return
	audio.call("stop_dialogue_voice")
