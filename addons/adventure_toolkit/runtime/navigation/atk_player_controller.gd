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

@export_group("Motion Easing")
## Ease into walk speed and ease out before stopping. Disable for the old instant-speed motion.
@export var motion_easing_enabled := true
## How quickly speed ramps up toward [member move_speed] (units per second squared).
@export_range(0.1, 80.0, 0.1, "or_greater") var acceleration := 8.0
## How quickly speed ramps down when slowing or stopping (units per second squared).
@export_range(0.1, 80.0, 0.1, "or_greater") var deceleration := 12.0
## If on, speed is capped so the player can come to rest at the click point instead of overshooting.
@export var arrival_slowdown := true
## How quickly facing/direction turns toward the path (higher = snappier turns).
@export_range(0.1, 80.0, 0.1, "or_greater") var turn_acceleration := 10.0
## Optional 0–1 curve sampled along the current trip (0 = start, 1 = arrival). Multiplies [member move_speed].
## Leave empty to use acceleration / deceleration only.
@export var speed_curve: Curve

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

var _has_active_destination := false
var _current_destination := Vector3.ZERO
var _pending_interaction_target: ATKAdventureObject = null
var _pending_interaction_verb := "interact"
var _active_interaction_verb := "interact"
var _active_arrival_threshold := 0.15
var _current_speed := 0.0
var _move_direction := Vector3.ZERO
var _trip_length := 0.0


func _ready() -> void:
	add_to_group("atk_player")
	add_to_group("atk_player_start")
	motion_mode = MOTION_MODE_FLOATING
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
	_reset_motion_state()


func _reset_motion_state() -> void:
	velocity = Vector3.ZERO
	_current_speed = 0.0
	_move_direction = Vector3.ZERO
	_trip_length = 0.0


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


func _physics_process(delta: float) -> void:
	# Scene transitions can invoke one more physics tick while this node (or its physics body)
	# is being detached. Guard hard to avoid null-space and not-inside-tree engine errors.
	if not is_inside_tree() or get_world_3d() == null:
		return
	if navigation_agent == null or not navigation_agent.is_inside_tree():
		return

	if _is_world_interaction_locked():
		_clear_active_movement()
		_apply_planar_motion()
		return
	if not _has_active_destination:
		_apply_idle_motion(delta)
		return

	# Must query the agent every physics frame or a new click never gets a path.
	var next_path_position := navigation_agent.get_next_path_position()

	if _is_destination_reached():
		_finish_destination()
		_apply_planar_motion()
		return

	var desired_direction := _horizontal_direction_to(next_path_position)
	_move_direction = _blend_move_direction(desired_direction, delta)
	_current_speed = _step_current_speed(delta)
	velocity = _move_direction * _current_speed

	if _current_speed > 0.08 and _move_direction.length_squared() > 0.0001:
		look_at(global_position + _move_direction, Vector3.UP)

	_apply_planar_motion()


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
	_reset_motion_state()
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
	if _horizontal_distance_to(_current_destination) <= _active_arrival_threshold:
		return true

	var path := navigation_agent.get_current_navigation_path()
	if path.size() > 1 and navigation_agent.is_navigation_finished():
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
	_trip_length = maxf(_horizontal_distance_to(_current_destination), 0.001)
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


func _horizontal_direction_to(world_point: Vector3) -> Vector3:
	var offset := Vector3(world_point.x - global_position.x, 0.0, world_point.z - global_position.z)
	if offset.length_squared() < 0.000001:
		return Vector3.ZERO
	return offset.normalized()


func _horizontal_distance_to(world_point: Vector3) -> float:
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var there := Vector3(world_point.x, 0.0, world_point.z)
	return here.distance_to(there)


func _blend_move_direction(desired_direction: Vector3, delta: float) -> Vector3:
	if desired_direction.length_squared() < 0.000001:
		return _move_direction
	if _move_direction.length_squared() < 0.000001 or not motion_easing_enabled:
		return desired_direction
	var step := maxf(turn_acceleration, 0.01) * delta
	var blended := _move_direction.move_toward(desired_direction, step)
	if blended.length_squared() < 0.000001:
		return desired_direction
	return blended.normalized()


func _step_current_speed(delta: float) -> float:
	var remaining := _horizontal_distance_to(_current_destination)
	var desired_speed := _desired_walk_speed(remaining)
	if not motion_easing_enabled:
		return desired_speed
	var rate := acceleration if desired_speed > _current_speed else deceleration
	return move_toward(_current_speed, desired_speed, maxf(rate, 0.01) * delta)


func _desired_walk_speed(remaining: float) -> float:
	var desired := maxf(move_speed, 0.0)
	if speed_curve != null and speed_curve.point_count > 0 and _trip_length > 0.001:
		var traveled := clampf(1.0 - (remaining / _trip_length), 0.0, 1.0)
		desired *= clampf(speed_curve.sample(traveled), 0.0, 1.0)
	if not motion_easing_enabled:
		return desired
	if not arrival_slowdown:
		return desired
	var stop_distance := maxf(remaining - _active_arrival_threshold, 0.0)
	var max_stoppable := sqrt(2.0 * maxf(deceleration, 0.01) * stop_distance)
	return minf(desired, max_stoppable)


func _apply_idle_motion(delta: float) -> void:
	if motion_easing_enabled and _current_speed > 0.01:
		_current_speed = move_toward(_current_speed, 0.0, maxf(deceleration, 0.01) * delta)
		velocity = _move_direction * _current_speed
	else:
		_reset_motion_state()
	_apply_planar_motion()


func _apply_planar_motion() -> void:
	velocity.y = 0.0
	_safe_move_and_slide()


func _safe_move_and_slide() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if get_world_3d() == null:
		return
	move_and_slide()
