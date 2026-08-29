@tool
class_name ATKSceneCamera
extends Camera3D

## Authored adventure camera. Modes:
## - [constant CameraBehavior.STATIC]: stays where you placed it.
## - [constant CameraBehavior.FOLLOW_PLAYER]: slides after the player crosses a screen/world deadzone.
## - [constant CameraBehavior.LOOK_AT_PLAYER]: stays in place and turns to face the player.


enum CameraBehavior {
	STATIC,
	FOLLOW_PLAYER,
	LOOK_AT_PLAYER,
}

enum FollowDeadzoneMode {
	## World-unit band around the current screen center.
	WORLD,
	## Band as a fraction of the visible half-width at the player. 0 = exact midpoint.
	VIEW,
}


@export var behavior: CameraBehavior = CameraBehavior.STATIC:
	set(value):
		behavior = value
		_queue_gizmo_refresh()
@export var follow_target_path: NodePath

@export_group("Follow Player")
@export var follow_x := true:
	set(value):
		follow_x = value
		_queue_gizmo_refresh()
@export var follow_y := false:
	set(value):
		follow_y = value
		_queue_gizmo_refresh()
@export var follow_z := false:
	set(value):
		follow_z = value
		_queue_gizmo_refresh()
@export_range(0.0, 40.0, 0.1, "or_greater") var follow_smoothing := 6.0
@export var capture_offset_on_ready := true
@export var follow_offset := Vector3.ZERO
@export var use_follow_limits := false:
	set(value):
		use_follow_limits = value
		_queue_gizmo_refresh()
@export var follow_limit_min := Vector3(-50, -50, -50):
	set(value):
		follow_limit_min = value
		_queue_gizmo_refresh()
@export var follow_limit_max := Vector3(50, 50, 50):
	set(value):
		follow_limit_max = value
		_queue_gizmo_refresh()

@export_group("Follow Deadzone")
## Stay still until the player walks out of this band (Mr. Prepper-style).
@export var follow_deadzone_enabled := true:
	set(value):
		follow_deadzone_enabled = value
		_queue_gizmo_refresh()
@export var follow_deadzone_mode: FollowDeadzoneMode = FollowDeadzoneMode.VIEW:
	set(value):
		follow_deadzone_mode = value
		_queue_gizmo_refresh()
@export var follow_deadzone := Vector3(2.0, 1.0, 2.0):
	set(value):
		follow_deadzone = value
		_queue_gizmo_refresh()
## 0 = scroll starts at the screen midpoint. Raise to wait longer.
@export_range(0.0, 0.95, 0.01) var follow_deadzone_view_x := 0.0:
	set(value):
		follow_deadzone_view_x = value
		_queue_gizmo_refresh()
@export_range(0.0, 0.95, 0.01) var follow_deadzone_view_y := 0.0:
	set(value):
		follow_deadzone_view_y = value
		_queue_gizmo_refresh()

@export_group("Look At Player")
@export_range(0.0, 40.0, 0.1, "or_greater") var look_smoothing := 6.0
@export var look_at_height := 0.9

@export_group("Activation")
@export var update_only_when_current := true
@export var snap_on_activate := true

@export_group("Gizmos")
## Select this camera in the 3D view to drag rail, limit, and deadzone handles.
@export var show_follow_gizmos := true:
	set(value):
		show_follow_gizmos = value
		_queue_gizmo_refresh()
@export var show_gizmos_in_game := false
@export var gizmo_floor_y := 0.05:
	set(value):
		gizmo_floor_y = value
		_queue_gizmo_refresh()
@export var gizmo_rail_length := 16.0:
	set(value):
		gizmo_rail_length = value
		_queue_gizmo_refresh()


var _player: Node3D
var _rest_position := Vector3.ZERO
var _held_position := Vector3.ZERO
var _offset_captured := false
var _window_ready := false
var _window_min := Vector3.ZERO
var _window_max := Vector3.ZERO
var _gizmo_instance := RID()
var _gizmo_mesh: ImmediateMesh


func _ready() -> void:
	set_process(true)
	set_notify_transform(true)
	_rest_position = global_position
	_held_position = global_position
	var leftover := get_node_or_null("ATKFollowGizmo")
	if leftover != null:
		remove_child(leftover)
		leftover.free()
	if Engine.is_editor_hint():
		return
	call_deferred("_capture_follow_state")


func _exit_tree() -> void:
	_free_gizmo()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if Engine.is_editor_hint() and behavior == CameraBehavior.FOLLOW_PLAYER:
			_rest_position = global_position
			_held_position = global_position
			_queue_gizmo_refresh()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var should_draw := show_gizmos_in_game and show_follow_gizmos and behavior == CameraBehavior.FOLLOW_PLAYER
	if should_draw:
		_update_gizmo()
	else:
		_hide_gizmo()


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
	_held_position = global_position
	var player := _resolve_player()
	if player == null:
		return
	if capture_offset_on_ready and not _offset_captured:
		follow_offset = global_position - player.global_position
		_offset_captured = true
	_rebuild_deadzone_window(player)


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
	if not _window_ready:
		_rebuild_deadzone_window(player)
	var desired := _rest_position
	var player_pos := player.global_position
	if follow_deadzone_enabled:
		_slide_deadzone_window(player_pos, _deadzone_extents(player_pos))
		if follow_x:
			desired.x = _held_position.x
		if follow_y:
			desired.y = _held_position.y
		if follow_z:
			desired.z = _held_position.z
	else:
		var tracked := player_pos + follow_offset
		if follow_x:
			desired.x = tracked.x
		if follow_y:
			desired.y = tracked.y
		if follow_z:
			desired.z = tracked.z
		_held_position = desired
	if use_follow_limits:
		desired.x = clampf(desired.x, follow_limit_min.x, follow_limit_max.x)
		desired.y = clampf(desired.y, follow_limit_min.y, follow_limit_max.y)
		desired.z = clampf(desired.z, follow_limit_min.z, follow_limit_max.z)
		_held_position.x = desired.x if follow_x else _held_position.x
		_held_position.y = desired.y if follow_y else _held_position.y
		_held_position.z = desired.z if follow_z else _held_position.z
	if weight >= 0.999:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, weight)


func _rebuild_deadzone_window(player: Node3D) -> void:
	var player_pos := player.global_position
	var dz := _deadzone_extents(player_pos)
	_held_position = _rest_position
	_window_min = _held_position - dz
	_window_max = _held_position + dz
	# Include the player's current place in the frame so we do not snap on start.
	if follow_x:
		_window_min.x = minf(_window_min.x, player_pos.x)
		_window_max.x = maxf(_window_max.x, player_pos.x)
	if follow_y:
		_window_min.y = minf(_window_min.y, player_pos.y)
		_window_max.y = maxf(_window_max.y, player_pos.y)
	if follow_z:
		_window_min.z = minf(_window_min.z, player_pos.z)
		_window_max.z = maxf(_window_max.z, player_pos.z)
	_window_ready = true


func _slide_deadzone_window(player_pos: Vector3, dz: Vector3) -> void:
	if follow_x:
		if player_pos.x > _window_max.x:
			_window_max.x = player_pos.x
			_window_min.x = player_pos.x - 2.0 * maxf(dz.x, 0.001)
			_held_position.x = player_pos.x - maxf(dz.x, 0.001)
		elif player_pos.x < _window_min.x:
			_window_min.x = player_pos.x
			_window_max.x = player_pos.x + 2.0 * maxf(dz.x, 0.001)
			_held_position.x = player_pos.x + maxf(dz.x, 0.001)
	if follow_y:
		if player_pos.y > _window_max.y:
			_window_max.y = player_pos.y
			_window_min.y = player_pos.y - 2.0 * maxf(dz.y, 0.001)
			_held_position.y = player_pos.y - maxf(dz.y, 0.001)
		elif player_pos.y < _window_min.y:
			_window_min.y = player_pos.y
			_window_max.y = player_pos.y + 2.0 * maxf(dz.y, 0.001)
			_held_position.y = player_pos.y + maxf(dz.y, 0.001)
	if follow_z:
		if player_pos.z > _window_max.z:
			_window_max.z = player_pos.z
			_window_min.z = player_pos.z - 2.0 * maxf(dz.z, 0.001)
			_held_position.z = player_pos.z - maxf(dz.z, 0.001)
		elif player_pos.z < _window_min.z:
			_window_min.z = player_pos.z
			_window_max.z = player_pos.z + 2.0 * maxf(dz.z, 0.001)
			_held_position.z = player_pos.z + maxf(dz.z, 0.001)


func _deadzone_extents(at_point: Vector3) -> Vector3:
	if follow_deadzone_mode == FollowDeadzoneMode.WORLD:
		return Vector3(maxf(follow_deadzone.x, 0.0), maxf(follow_deadzone.y, 0.0), maxf(follow_deadzone.z, 0.0))
	var half := _view_half_extents_at(at_point)
	return Vector3(half.x * follow_deadzone_view_x, half.y * follow_deadzone_view_y, half.x * follow_deadzone_view_x)


func _view_half_extents_at(world_point: Vector3) -> Vector2:
	var depth := absf((world_point - global_position).dot(-global_transform.basis.z))
	depth = maxf(depth, 0.5)
	var half_h := tan(deg_to_rad(fov * 0.5)) * depth
	var aspect := 16.0 / 9.0
	var vp := get_viewport()
	if vp != null:
		var size := vp.get_visible_rect().size
		if size.y > 0.001:
			aspect = size.x / size.y
	return Vector2(half_h * aspect, half_h)


func _look_point_on_floor() -> Vector3:
	var look_dir := -global_transform.basis.z
	if absf(look_dir.y) < 0.001:
		return Vector3(global_position.x, gizmo_floor_y, global_position.z)
	var t := (gizmo_floor_y - global_position.y) / look_dir.y
	if t < 0.1:
		return Vector3(global_position.x, gizmo_floor_y, global_position.z)
	var point := global_position + look_dir * t
	point.y = gizmo_floor_y
	return point


func get_follow_gizmo_layout() -> Dictionary:
	var look := _look_point_on_floor()
	var x0 := look.x
	var x1 := look.x
	var z0 := look.z
	var z1 := look.z
	if follow_x:
		if use_follow_limits:
			x0 = follow_limit_min.x
			x1 = follow_limit_max.x
		else:
			x0 = look.x - gizmo_rail_length * 0.5
			x1 = look.x + gizmo_rail_length * 0.5
	if follow_z:
		if use_follow_limits:
			z0 = follow_limit_min.z
			z1 = follow_limit_max.z
		else:
			z0 = look.z - gizmo_rail_length * 0.5
			z1 = look.z + gizmo_rail_length * 0.5
	var at_point := look
	var player := _resolve_player()
	if player != null:
		at_point = player.global_position
	var dz := _deadzone_extents(at_point)
	return {
		"look": look,
		"floor_y": gizmo_floor_y,
		"x0": x0,
		"x1": x1,
		"z0": z0,
		"z1": z1,
		"dz": dz,
		"dz_min_x": look.x - (dz.x if follow_x else 0.45),
		"dz_max_x": look.x + (dz.x if follow_x else 0.45),
		"dz_min_z": look.z - (dz.z if follow_z else 1.4),
		"dz_max_z": look.z + (dz.z if follow_z else 1.4),
		"view_half": _view_half_extents_at(at_point),
	}


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


func _queue_gizmo_refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_gizmos()


func _hide_gizmo() -> void:
	if _gizmo_instance.is_valid():
		RenderingServer.instance_set_visible(_gizmo_instance, false)


func _free_gizmo() -> void:
	if _gizmo_instance.is_valid():
		RenderingServer.free_rid(_gizmo_instance)
		_gizmo_instance = RID()
	_gizmo_mesh = null


func _update_gizmo() -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	if not _ensure_gizmo():
		return
	_gizmo_mesh.clear_surfaces()
	var line_mat := _gizmo_line_material()
	var fill_mat := _gizmo_fill_material()
	_draw_deadzone_fill(_gizmo_mesh, fill_mat)
	_draw_rail_and_limits(_gizmo_mesh, line_mat)
	RenderingServer.instance_set_scenario(_gizmo_instance, get_world_3d().scenario)
	RenderingServer.instance_set_base(_gizmo_instance, _gizmo_mesh.get_rid())
	RenderingServer.instance_set_transform(_gizmo_instance, Transform3D.IDENTITY)
	RenderingServer.instance_set_visible(_gizmo_instance, true)


func _ensure_gizmo() -> bool:
	if _gizmo_mesh == null:
		_gizmo_mesh = ImmediateMesh.new()
	if not _gizmo_instance.is_valid():
		_gizmo_instance = RenderingServer.instance_create()
	return _gizmo_instance.is_valid()


func _gizmo_line_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	mat.no_depth_test = true
	return mat


func _gizmo_fill_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.no_depth_test = true
	return mat


func _draw_rail_and_limits(mesh: ImmediateMesh, mat: Material) -> void:
	var look := _look_point_on_floor()
	var y := gizmo_floor_y
	var x0 := look.x - gizmo_rail_length * 0.5
	var x1 := look.x + gizmo_rail_length * 0.5
	var z0 := look.z
	var z1 := look.z
	if follow_x:
		if use_follow_limits:
			x0 = follow_limit_min.x
			x1 = follow_limit_max.x
	else:
		x0 = look.x
		x1 = look.x
	if follow_z:
		if use_follow_limits:
			z0 = follow_limit_min.z
			z1 = follow_limit_max.z
		else:
			z0 = look.z - gizmo_rail_length * 0.5
			z1 = look.z + gizmo_rail_length * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_set_color(Color(0.15, 0.9, 1.0, 1.0))
	for offset in [-0.06, 0.0, 0.06]:
		_add_world_line(mesh, Vector3(x0, y, z0 + offset), Vector3(x1, y, z1 + offset))
	if use_follow_limits:
		mesh.surface_set_color(Color(1.0, 0.4, 0.1, 1.0))
		_add_limit_post(mesh, Vector3(x0, y, look.z))
		_add_limit_post(mesh, Vector3(x1, y, look.z))
	mesh.surface_end()


func _draw_deadzone_fill(mesh: ImmediateMesh, mat: Material) -> void:
	if not follow_deadzone_enabled:
		return
	var look := _look_point_on_floor()
	var y := gizmo_floor_y
	var player := _resolve_player()
	var at_point := player.global_position if player != null else look
	var dz := _deadzone_extents(at_point)
	var min_x := look.x - (dz.x if follow_x else 0.4)
	var max_x := look.x + (dz.x if follow_x else 0.4)
	var min_z := look.z - (dz.z if follow_z else 1.2)
	var max_z := look.z + (dz.z if follow_z else 1.2)
	if _window_ready:
		if follow_x:
			min_x = _window_min.x
			max_x = _window_max.x
		if follow_z:
			min_z = _window_min.z
			max_z = _window_max.z
	if not follow_x:
		min_x = look.x - 0.45
		max_x = look.x + 0.45
	if not follow_z:
		min_z = look.z - 1.4
		max_z = look.z + 1.4
	var p0 := Vector3(min_x, y, min_z)
	var p1 := Vector3(max_x, y, min_z)
	var p2 := Vector3(max_x, y, max_z)
	var p3 := Vector3(min_x, y, max_z)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	mesh.surface_set_color(Color(1.0, 0.85, 0.15, 0.22))
	mesh.surface_add_vertex(p0)
	mesh.surface_add_vertex(p1)
	mesh.surface_add_vertex(p2)
	mesh.surface_add_vertex(p0)
	mesh.surface_add_vertex(p2)
	mesh.surface_add_vertex(p3)
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	mesh.surface_set_color(Color(1.0, 0.75, 0.1, 1.0))
	mesh.surface_add_vertex(p0)
	mesh.surface_add_vertex(p1)
	mesh.surface_add_vertex(p2)
	mesh.surface_add_vertex(p3)
	mesh.surface_add_vertex(p0)
	mesh.surface_end()


func _add_limit_post(mesh: ImmediateMesh, world_pos: Vector3) -> void:
	_add_world_line(mesh, world_pos, world_pos + Vector3(0.0, 1.8, 0.0))
	_add_world_line(mesh, world_pos + Vector3(-0.35, 0.0, 0.0), world_pos + Vector3(0.35, 0.0, 0.0))
	_add_world_line(mesh, world_pos + Vector3(0.0, 0.0, -0.35), world_pos + Vector3(0.0, 0.0, 0.35))


func _add_world_line(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)


func _add_line(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	_add_world_line(mesh, a, b)
