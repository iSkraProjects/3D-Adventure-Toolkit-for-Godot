class_name ATKSceneCamera
extends Camera3D

## Authored adventure camera. Modes:
## - [constant CameraBehavior.STATIC]: stays where you placed it.
## - [constant CameraBehavior.FOLLOW_PLAYER]: slides with the player on unlocked axes (side-scroll, etc.).
## - [constant CameraBehavior.LOOK_AT_PLAYER]: stays in place and turns to face the player.


enum CameraBehavior {
	STATIC,
	FOLLOW_PLAYER,
	LOOK_AT_PLAYER,
}


@export var behavior: CameraBehavior = CameraBehavior.STATIC
@export var follow_target_path: NodePath

@export_group("Follow Player")
## World X (left/right in a typical +Z-facing shot).
@export var follow_x := true
## World Y (up/down). Leave off to keep the authored camera height.
@export var follow_y := false
## World Z (in/out). Leave off for a left/right scroll only.
@export var follow_z := false
## 0 = snap. Higher = smoother catch-up.
@export_range(0.0, 40.0, 0.1, "or_greater") var follow_smoothing := 6.0
## If on, keep the camera’s starting gap from the player on followed axes.
@export var capture_offset_on_ready := true
@export var follow_offset := Vector3.ZERO
@export var use_follow_limits := false
@export var follow_limit_min := Vector3(-50, -50, -50)
@export var follow_limit_max := Vector3(50, 50, 50)

@export_group("Look At Player")
@export_range(0.0, 40.0, 0.1, "or_greater") var look_smoothing := 6.0
## Extra height on the look target (chest/head).
@export var look_at_height := 0.9

@export_group("Activation")
## If on, only move/look while this camera is the active (current) camera.
@export var update_only_when_current := true
## Snap into place when the director makes this camera current.
@export var snap_on_activate := true


var _player: Node3D
var _rest_position := Vector3.ZERO
var _offset_captured := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_rest_position = global_position
	call_deferred("_capture_follow_state")


func notify_camera_activated() -> void:
	if snap_on_activate and behavior != CameraBehavior.STATIC:
		_apply_behavior(1.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if update_only_when_current and not current:
		return
	if behavior == CameraBehavior.STATIC:
		return
	_apply_behavior(_smooth_weight(follow_smoothing if behavior == CameraBehavior.FOLLOW_PLAYER else look_smoothing, delta))


func _capture_follow_state() -> void:
	_rest_position = global_position
	var player := _resolve_player()
	if player == null:
		return
	if capture_offset_on_ready and not _offset_captured:
		follow_offset = global_position - player.global_position
		_offset_captured = true


func _apply_behavior(weight: float) -> void:
	var player := _resolve_player()
	if player == null:
		return
	if not _offset_captured:
		_capture_follow_state()
	match behavior:
		CameraBehavior.FOLLOW_PLAYER:
			_apply_follow(player, weight)
		CameraBehavior.LOOK_AT_PLAYER:
			_apply_look_at(player, weight)
		_:
			pass


func _apply_follow(player: Node3D, weight: float) -> void:
	var desired := _rest_position
	var tracked := player.global_position + follow_offset
	if follow_x:
		desired.x = tracked.x
	if follow_y:
		desired.y = tracked.y
	if follow_z:
		desired.z = tracked.z
	if use_follow_limits:
		desired.x = clampf(desired.x, follow_limit_min.x, follow_limit_max.x)
		desired.y = clampf(desired.y, follow_limit_min.y, follow_limit_max.y)
		desired.z = clampf(desired.z, follow_limit_min.z, follow_limit_max.z)
	if weight >= 0.999:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, weight)


func _apply_look_at(player: Node3D, weight: float) -> void:
	global_position = _rest_position
	var look_target := player.global_position + Vector3(0.0, look_at_height, 0.0)
	if global_position.is_equal_approx(look_target):
		return
	var from := global_transform
	look_at(look_target, Vector3.UP)
	if weight >= 0.999:
		return
	global_transform = from.interpolate_with(global_transform, weight)


func _smooth_weight(smoothing: float, delta: float) -> float:
	if smoothing <= 0.001:
		return 1.0
	return 1.0 - exp(-smoothing * delta)


func _resolve_player() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	if not follow_target_path.is_empty():
		var n := get_node_or_null(follow_target_path)
		if n is Node3D:
			_player = n as Node3D
			return _player
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("atk_player"):
		if n is Node3D:
			_player = n as Node3D
			return _player
	return null
