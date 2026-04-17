class_name ATKPlayerController
extends CharacterBody3D


signal destination_requested(target_position: Vector3)
signal destination_reached(target_position: Vector3)
signal interaction_requested(target: Node)
signal interaction_started(target: Node)
signal interaction_finished(target: Node)


@export var move_speed := 4.0
@export var arrival_threshold := 0.15
@export var interaction_arrival_threshold := 0.9
## When walking to an [ATKAdventureObject] interaction marker, the agent may stop against the
## object's collider before reaching the marker (e.g. marker on the "front" while the player
## approaches from behind). If [member interaction_relaxed_completion_enabled], we also accept
## arrival when the player is near the object's root and within [member interaction_relaxed_marker_distance]
## of the marker — enough to talk without clipping through geometry.
@export var interaction_relaxed_completion_enabled := true
@export var interaction_relaxed_object_distance := 1.75
@export var interaction_relaxed_marker_distance := 2.85
@export var floor_y := 0.0

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var _has_active_destination := false
var _current_destination := Vector3.ZERO
var _pending_interaction_target: ATKAdventureObject = null
var _pending_interaction_verb := "interact"
var _active_interaction_verb := "interact"
var _active_arrival_threshold := 0.15


func _ready() -> void:
	add_to_group("atk_player")
	add_to_group("atk_player_start")
	_active_arrival_threshold = arrival_threshold
	navigation_agent.path_desired_distance = _active_arrival_threshold
	navigation_agent.target_desired_distance = _active_arrival_threshold


func _is_world_interaction_locked() -> bool:
	var w := get_node_or_null("/root/ATKWorldUi")
	if w != null and w.has_method("is_world_interaction_locked"):
		return bool(w.call("is_world_interaction_locked"))
	var dlg := get_node_or_null("/root/ATKDialogue")
	if dlg != null and dlg.has_method("is_active") and bool(dlg.call("is_active")):
		return true
	var inv_ui := get_node_or_null("/root/ATKInventory/DefaultInventoryUI")
	if inv_ui != null and inv_ui.has_method("is_inventory_panel_open"):
		if bool(inv_ui.call("is_inventory_panel_open")):
			return true
	var journal_ui := get_node_or_null("/root/ATKJournal/DefaultObjectiveJournalUI")
	if journal_ui != null and journal_ui.has_method("is_journal_panel_open"):
		if bool(journal_ui.call("is_journal_panel_open")):
			return true
	var hint_ui := get_node_or_null("/root/ATKHints/DefaultHintUI")
	if hint_ui != null and hint_ui.has_method("is_hint_panel_open"):
		if bool(hint_ui.call("is_hint_panel_open")):
			return true
	var feedback := get_node_or_null("/root/ATKInteractionFeedback")
	if feedback != null and feedback.has_method("is_interaction_message_open"):
		if bool(feedback.call("is_interaction_message_open")):
			return true
	return false


func _clear_active_movement() -> void:
	_has_active_destination = false
	_pending_interaction_target = null
	velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if _is_world_interaction_locked():
		return
	if event is not InputEventMouseButton:
		return
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return

	var clicked_object := _get_clicked_adventure_object(event.position)
	if clicked_object != null and clicked_object.can_interact():
		var verb := "inspect" if event.button_index == MOUSE_BUTTON_RIGHT else "interact"
		request_interaction(clicked_object, verb)
		return

	# Right-click is reserved for inspect on world objects.
	if event.button_index == MOUSE_BUTTON_RIGHT:
		return

	var target_position := _get_ground_click_position(event.position)
	if target_position == null:
		return

	request_destination(target_position)


func _physics_process(_delta: float) -> void:
	# Scene transitions can invoke one more physics tick while this node (or its physics body)
	# is being detached. Guard hard to avoid null-space and not-inside-tree engine errors.
	if not is_inside_tree() or get_world_3d() == null:
		return
	if navigation_agent == null or not navigation_agent.is_inside_tree():
		return

	if _is_world_interaction_locked():
		_clear_active_movement()
		_safe_move_and_slide()
		return
	if not _has_active_destination:
		velocity = Vector3.ZERO
		_safe_move_and_slide()
		return

	if _is_destination_reached():
		_finish_destination()
		return

	var next_path_position := navigation_agent.get_next_path_position()
	var move_direction := global_position.direction_to(next_path_position)
	velocity = move_direction * move_speed

	if velocity.length_squared() > 0.001:
		look_at(global_position + Vector3(velocity.x, 0.0, velocity.z), Vector3.UP)

	_safe_move_and_slide()


func request_destination(target_position: Vector3) -> void:
	_cancel_pending_interaction()
	_set_destination(target_position, arrival_threshold)


func request_interaction(target: ATKAdventureObject, verb: String = "interact") -> void:
	_pending_interaction_target = target
	var resolved_verb := verb.strip_edges().to_lower()
	_pending_interaction_verb = resolved_verb if not resolved_verb.is_empty() else "interact"
	emit_signal("interaction_requested", target)
	ATKLog.debug("Interaction requested for '%s' verb='%s'." % [target.name, _pending_interaction_verb], "ATKInteraction")
	_set_destination(target.get_interaction_position(), maxf(arrival_threshold, interaction_arrival_threshold))


func _finish_destination() -> void:
	_has_active_destination = false
	velocity = Vector3.ZERO
	emit_signal("destination_reached", _current_destination)

	if _pending_interaction_target != null:
		await _perform_pending_interaction()


func _perform_pending_interaction() -> void:
	var target := _pending_interaction_target
	_pending_interaction_target = null
	if target == null or not is_instance_valid(target):
		return

	var facing_target := target.get_facing_target()
	if facing_target != null:
		look_at(Vector3(facing_target.global_position.x, global_position.y, facing_target.global_position.z), Vector3.UP)

	emit_signal("interaction_started", target)
	ATKLog.info("Interacting with '%s'." % (target.display_name if not target.display_name.is_empty() else target.name), "ATKInteraction")
	_active_interaction_verb = _pending_interaction_verb
	_pending_interaction_verb = "interact"
	await target.interact_default(self)
	_active_interaction_verb = "interact"
	emit_signal("interaction_finished", target)


func _is_destination_reached() -> bool:
	if navigation_agent.is_navigation_finished():
		return true

	if global_position.distance_to(_current_destination) <= _active_arrival_threshold:
		return true

	if (
		interaction_relaxed_completion_enabled
		and _pending_interaction_target != null
		and is_instance_valid(_pending_interaction_target)
	):
		var marker := _pending_interaction_target.get_interaction_position()
		var obj_pos := _pending_interaction_target.global_position
		var flat_player := Vector3(global_position.x, floor_y, global_position.z)
		var flat_marker := Vector3(marker.x, floor_y, marker.z)
		var flat_obj := Vector3(obj_pos.x, floor_y, obj_pos.z)
		if flat_player.distance_to(flat_obj) <= interaction_relaxed_object_distance:
			if flat_player.distance_to(flat_marker) <= interaction_relaxed_marker_distance:
				return true

	return false


func _set_destination(target_position: Vector3, desired_threshold: float) -> void:
	_active_arrival_threshold = desired_threshold
	_current_destination = Vector3(target_position.x, floor_y, target_position.z)
	_has_active_destination = true
	navigation_agent.path_desired_distance = _active_arrival_threshold
	navigation_agent.target_desired_distance = _active_arrival_threshold
	navigation_agent.target_position = _current_destination
	emit_signal("destination_requested", _current_destination)


func _cancel_pending_interaction() -> void:
	_pending_interaction_target = null
	_pending_interaction_verb = "interact"


func _get_ground_click_position(mouse_position: Vector2) -> Variant:
	var viewport := get_viewport()
	if viewport == null:
		return null

	var camera := viewport.get_camera_3d()
	if camera == null:
		return null

	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if absf(ray_direction.y) < 0.0001:
		return null

	var distance := (floor_y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return null

	return ray_origin + (ray_direction * distance)


func _get_clicked_adventure_object(mouse_position: Vector2) -> ATKAdventureObject:
	var viewport := get_viewport()
	if viewport == null:
		return null
	return ATKInteractionPointer.adventure_object_from_screen_pos(mouse_position, viewport, [self])


func get_requested_interaction_verb() -> String:
	return _active_interaction_verb


func _safe_move_and_slide() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if get_world_3d() == null:
		return
	move_and_slide()
