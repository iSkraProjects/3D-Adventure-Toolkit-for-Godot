@tool
class_name ATKAdventureObject
extends Node3D

signal object_runtime_state_changed(object_id: String, key: String, value: Variant, old_value: Variant)

enum HoverCursorIntent {
	AUTO,
	INTERACT,
	INSPECT,
	OPEN,
	ATTACK,
	CLIMB,
	DESCEND
}


@export var object_id := ""
@export var display_name := ""
@export_multiline var inspect_text := ""
## Optional UI icon for this object. Pickups can use this as inventory icon override.
@export var ui_icon: Texture2D
@export var interaction_point_path: NodePath
@export var is_enabled := true
@export var is_visible_in_world := true
@export var is_interactable := true
@export var interaction_rules: Array[ATKInteractionRule] = []
@export var fallback_rule: ATKInteractionRule

## If set, used instead of [member display_name] for hover nameplates ([ATKInteractionHover]).
@export var hover_tooltip_primary_override := ""
## Optional second line (state, hint). See also [ATKDoor.hover_tooltip_when_open].
@export_multiline var hover_tooltip_secondary := ""
## Local offset from the object origin for projecting the hover anchor (see [method get_hover_tooltip_world_position]).
@export var hover_tooltip_offset := Vector3(0, 1.25, 0)
## Cursor intent shown by [ATKInteractionHover] while hovering this object.
@export var hover_cursor_intent := HoverCursorIntent.AUTO
## Optional usability flags for designers. AUTO mode maps to these flags.
@export var is_openable := false
@export var is_attackable := false
@export var is_climbable := false
@export var is_descendable := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_load_persisted_runtime_state()
	visible = is_visible_in_world


func _get_configuration_warnings() -> PackedStringArray:
	return validate_configuration()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()


func validate_configuration() -> PackedStringArray:
	var issues := PackedStringArray()
	if object_id.is_empty():
		issues.append("ATKAdventureObject requires a stable object_id.")
	if display_name.is_empty():
		issues.append("ATKAdventureObject should define a display_name.")
	if not interaction_point_path.is_empty() and get_interaction_point() == null:
		issues.append("ATKAdventureObject references a missing interaction point.")
	return issues


func get_interaction_point() -> ATKInteractionPoint:
	if interaction_point_path.is_empty():
		return null

	var point := get_node_or_null(interaction_point_path)
	if point is ATKInteractionPoint:
		return point as ATKInteractionPoint
	return null


func get_interaction_position() -> Vector3:
	var point := get_interaction_point()
	if point != null:
		return point.get_approach_position()
	return global_position


func get_facing_target() -> Node3D:
	var point := get_interaction_point()
	if point != null:
		var facing_target := point.get_facing_target()
		if facing_target != null:
			return facing_target
	return self


func can_interact() -> bool:
	return is_enabled and is_interactable and is_visible_in_world


func get_hover_tooltip_primary() -> String:
	var o := hover_tooltip_primary_override.strip_edges()
	if not o.is_empty():
		return o
	if not display_name.strip_edges().is_empty():
		return display_name.strip_edges()
	if not object_id.is_empty():
		return object_id
	return String(name)


func get_hover_tooltip_secondary() -> String:
	return hover_tooltip_secondary.strip_edges()


func get_hover_tooltip_world_position() -> Vector3:
	return to_global(hover_tooltip_offset)


func get_hover_cursor_kind() -> String:
	match hover_cursor_intent:
		HoverCursorIntent.INTERACT:
			return "interact"
		HoverCursorIntent.INSPECT:
			return "inspect"
		HoverCursorIntent.OPEN:
			return "open"
		HoverCursorIntent.ATTACK:
			return "attack"
		HoverCursorIntent.CLIMB:
			return "climb"
		HoverCursorIntent.DESCEND:
			return "descend"
		_:
			return _resolve_auto_hover_cursor_kind()


func get_default_interaction_text() -> String:
	return inspect_text


func interact_default(actor: Node) -> void:
	if not can_interact():
		return

	var eval_ctx := _build_eval_context(actor)
	var active_verb := _resolve_active_verb(actor)
	var use_rules := not interaction_rules.is_empty() or fallback_rule != null

	if use_rules:
		var matched := _pick_matching_rule(eval_ctx, active_verb)
		if matched != null and _rule_has_actions(matched):
			ATKLog.info(
				"Rule matched for '%s' (rule_id='%s')." % [object_id, matched.rule_id],
				"ATKInteraction"
			)
			var action_ctx := _build_action_context(actor, active_verb)
			await ATKActionRunner.run_sequence(matched.actions, action_ctx, Callable())
			_increment_interaction_count()
			return

		if fallback_rule != null and _rule_has_actions(fallback_rule) and _fallback_applies(fallback_rule, eval_ctx, active_verb):
			ATKLog.info("Fallback rule used for '%s'." % object_id, "ATKInteraction")
			var fb_ctx := _build_action_context(actor, active_verb)
			await ATKActionRunner.run_sequence(fallback_rule.actions, fb_ctx, Callable())
			_increment_interaction_count()
			return

		ATKLog.info("No interaction rule matched for '%s' (legacy inspect)." % object_id, "ATKInteraction")

	_run_legacy_inspect(actor)


func set_runtime_enabled(value: bool) -> void:
	var old_value := is_enabled
	is_enabled = value
	_emit_runtime_state_changed("is_enabled", value, old_value)
	_persist_runtime_state_value("is_enabled", value)


func set_runtime_visible(value: bool) -> void:
	var old_value := is_visible_in_world
	is_visible_in_world = value
	visible = value
	_emit_runtime_state_changed("is_visible_in_world", value, old_value)
	_persist_runtime_state_value("is_visible_in_world", value)


func set_runtime_interactable(value: bool) -> void:
	var old_value := is_interactable
	is_interactable = value
	_emit_runtime_state_changed("is_interactable", value, old_value)
	_persist_runtime_state_value("is_interactable", value)


func get_interaction_count() -> int:
	var state := _get_state_manager()
	if state == null or object_id.is_empty():
		return 0
	return int(state.get_object(object_id, "interaction_count", 0))


func _increment_interaction_count() -> void:
	if object_id.is_empty():
		return

	var state := _get_state_manager()
	if state == null:
		return

	var current := int(state.get_object(object_id, "interaction_count", 0))
	current += 1
	state.set_object(object_id, "interaction_count", current)
	_emit_runtime_state_changed("interaction_count", current, current - 1)
	ATKLog.debug("Object '%s' interaction_count = %d" % [object_id, current], "ATKObjectState")


func _load_persisted_runtime_state() -> void:
	if object_id.is_empty():
		return

	var state := _get_state_manager()
	if state == null:
		return

	is_enabled = bool(state.get_object(object_id, "is_enabled", is_enabled))
	is_visible_in_world = bool(state.get_object(object_id, "is_visible_in_world", is_visible_in_world))
	is_interactable = bool(state.get_object(object_id, "is_interactable", is_interactable))

	# Backfill defaults on first load so state exists independently from node lifetime.
	state.set_object(object_id, "is_enabled", is_enabled)
	state.set_object(object_id, "is_visible_in_world", is_visible_in_world)
	state.set_object(object_id, "is_interactable", is_interactable)


func _persist_runtime_state_value(key: String, value: Variant) -> void:
	if object_id.is_empty():
		return
	var state := _get_state_manager()
	if state == null:
		return
	state.set_object(object_id, key, value)


func _emit_runtime_state_changed(key: String, value: Variant, old_value: Variant) -> void:
	if object_id.is_empty():
		return
	emit_signal("object_runtime_state_changed", object_id, key, value, old_value)


func _get_state_manager() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKState")


func _run_legacy_inspect(_actor: Node) -> void:
	_increment_interaction_count()

	var text := get_default_interaction_text()
	if text.is_empty():
		text = "%s." % (display_name if not display_name.is_empty() else name)

	ATKLog.info(text, "ATKInteraction")
	_push_interaction_message(text)


func _push_interaction_message(line: String) -> void:
	var bus := get_node_or_null("/root/ATKInteractionFeedback")
	if bus != null and bus.has_method("show_message"):
		var title := display_name if not display_name.is_empty() else name
		bus.show_message(line, title, object_id)


func _resolve_active_verb(actor: Node = null) -> String:
	if actor != null and actor.has_method("get_requested_interaction_verb"):
		var verb := str(actor.call("get_requested_interaction_verb")).strip_edges().to_lower()
		if not verb.is_empty():
			return verb
	return "interact"


func _build_eval_context(actor: Node) -> Dictionary:
	var ctx := {
		"object_id": object_id,
		"scene_id": _get_current_scene_id(),
		"actor": actor,
	}
	var state := _get_state_manager()
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


func _build_action_context(actor: Node, active_verb: String) -> ATKActionContext:
	var c := ATKActionContext.new()
	c.actor = actor
	c.target = self
	c.object_id = object_id
	c.scene_id = _get_current_scene_id()
	c.verb = active_verb
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory != null and inventory.has_method("get_selected_item"):
		c.selected_item_id = str(inventory.call("get_selected_item"))
	return c


func _get_current_scene_id() -> String:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null:
		return ""
	return str(scenes.current_scene_id)


func _pick_matching_rule(eval_ctx: Dictionary, active_verb: String) -> ATKInteractionRule:
	for rule in interaction_rules:
		if rule == null or rule.is_fallback:
			continue
		if not _rule_headers_match(rule, active_verb, eval_ctx):
			continue
		if rule.conditions != null:
			var res := ATKConditionEvaluator.evaluate(rule.conditions, eval_ctx, false)
			if not bool(res.get(ATKCondition.RESULT_KEY_PASSED, false)):
				ATKLog.debug(
					"Rule '%s' failed conditions: %s" % [rule.rule_id, str(res.get(ATKCondition.RESULT_KEY_REASON, ""))],
					"ATKInteraction"
				)
				continue
		return rule
	return null


func _fallback_applies(rule: ATKInteractionRule, eval_ctx: Dictionary, active_verb: String) -> bool:
	if not _rule_headers_match(rule, active_verb, eval_ctx):
		return false
	if rule.conditions != null:
		var res := ATKConditionEvaluator.evaluate(rule.conditions, eval_ctx, false)
		return bool(res.get(ATKCondition.RESULT_KEY_PASSED, false))
	return true


func _rule_headers_match(rule: ATKInteractionRule, active_verb: String, eval_ctx: Dictionary) -> bool:
	if not rule.verb.is_empty() and rule.verb != active_verb:
		return false
	if not rule.require_selected_item_id.is_empty():
		var selected := str(eval_ctx.get("selected_item_id", ""))
		if selected != rule.require_selected_item_id:
			return false
	return true


func _rule_has_actions(rule: ATKInteractionRule) -> bool:
	return rule != null and rule.actions != null and not rule.actions.steps.is_empty()


func _resolve_auto_hover_cursor_kind() -> String:
	if is_climbable:
		return "climb"
	if is_descendable:
		return "descend"
	if is_openable:
		return "open"
	if is_attackable:
		return "attack"
	return "interact"
