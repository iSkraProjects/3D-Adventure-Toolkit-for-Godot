class_name ATKTrigger
extends Area3D

signal trigger_entered(trigger_id: String, body: Node)
signal trigger_exited(trigger_id: String, body: Node)

@export var trigger_id := ""
@export var one_shot := false
@export var player_only := true
@export var entry_conditions: ATKCondition
@export var on_enter_actions: ATKActionSequence
@export var on_exit_actions: ATKActionSequence
@export var disable_after_enter := false

var _has_fired := false


func _ready() -> void:
	if body_entered.is_connected(_on_body_entered):
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not _can_process_body(body):
		return
	if one_shot and _has_fired:
		return
	if not _entry_conditions_pass(body):
		return
	emit_signal("trigger_entered", trigger_id, body)
	ATKLog.debug("Trigger entered '%s' by '%s'." % [_debug_id(), body.name], "ATKTrigger")
	await _run_actions(on_enter_actions, body, "trigger_enter")
	_has_fired = true
	if disable_after_enter:
		monitoring = false
		set_deferred("monitorable", false)


func _on_body_exited(body: Node) -> void:
	if not _can_process_body(body):
		return
	emit_signal("trigger_exited", trigger_id, body)
	ATKLog.debug("Trigger exited '%s' by '%s'." % [_debug_id(), body.name], "ATKTrigger")
	await _run_actions(on_exit_actions, body, "trigger_exit")


func reset_trigger() -> void:
	_has_fired = false
	monitoring = true
	monitorable = true


func _can_process_body(body: Node) -> bool:
	if body == null:
		return false
	if not player_only:
		return true
	return body.is_in_group("atk_player")


func _entry_conditions_pass(body: Node) -> bool:
	if entry_conditions == null:
		return true
	var res := ATKConditionEvaluator.evaluate(entry_conditions, _build_eval_context(body), false)
	return bool(res.get(ATKCondition.RESULT_KEY_PASSED, false))


func _run_actions(sequence: ATKActionSequence, body: Node, verb: String) -> void:
	if sequence == null or sequence.steps.is_empty():
		return
	var ctx := ATKActionContext.new()
	ctx.actor = body
	ctx.target = self
	ctx.scene_id = _current_scene_id()
	ctx.object_id = _debug_id()
	ctx.verb = verb
	await ATKActionRunner.run_sequence(sequence, ctx, Callable())


func _build_eval_context(body: Node) -> Dictionary:
	var ctx := {
		"actor": body,
		"scene_id": _current_scene_id(),
		"object_id": _debug_id(),
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
	return ctx


func _current_scene_id() -> String:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null:
		return ""
	return str(scenes.current_scene_id)


func _debug_id() -> String:
	return trigger_id if not trigger_id.strip_edges().is_empty() else name
