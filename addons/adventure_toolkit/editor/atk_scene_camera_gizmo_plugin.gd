@tool
extends EditorNode3DGizmoPlugin

## Viewport handles for ATKSceneCamera follow rails, limits, and deadzone.
## Draws through Godot's editor gizmo system — no scene-tree children, safe to save.

const _CAMERA_SCRIPT := preload("res://addons/adventure_toolkit/runtime/camera/atk_scene_camera.gd")

const HANDLE_LIMIT_MIN_X := 0
const HANDLE_LIMIT_MAX_X := 1
const HANDLE_LIMIT_MIN_Z := 2
const HANDLE_LIMIT_MAX_Z := 3
const HANDLE_DEAD_NEG_X := 4
const HANDLE_DEAD_POS_X := 5
const HANDLE_DEAD_NEG_Z := 6
const HANDLE_DEAD_POS_Z := 7

const _MIN_LIMIT_GAP := 0.25
const _HANDLE_HEIGHT := 1.35
const _DEADZONE_SNAP := 0.12

var _fill_material: StandardMaterial3D


func _init() -> void:
	create_material("rail", Color(0.15, 0.9, 1.0, 1.0), false, true)
	create_material("limit", Color(1.0, 0.45, 0.1, 1.0), false, true)
	create_material("deadzone", Color(1.0, 0.8, 0.12, 1.0), false, true)
	create_handle_material("handles", false)
	create_handle_material("handles_secondary", false)
	_fill_material = StandardMaterial3D.new()
	_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_material.albedo_color = Color(1.0, 0.85, 0.15, 0.18)
	_fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill_material.disable_receive_shadows = true
	_fill_material.no_depth_test = true


func _get_gizmo_name() -> String:
	return "ATKSceneCamera Follow"


func _get_priority() -> int:
	return 80


func _has_gizmo(node: Node3D) -> bool:
	return node.get_script() == _CAMERA_SCRIPT


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var cam := gizmo.get_node_3d()
	if cam == null or not cam.show_follow_gizmos:
		return
	if cam.behavior != cam.CameraBehavior.FOLLOW_PLAYER:
		return
	var layout: Dictionary = cam.get_follow_gizmo_layout()
	var look: Vector3 = layout.look
	var y: float = layout.floor_y
	var x0: float = layout.x0
	var x1: float = layout.x1
	var z0: float = layout.z0
	var z1: float = layout.z1

	var rail := PackedVector3Array()
	if cam.follow_x:
		for offset in [-0.06, 0.0, 0.06]:
			_append_line(cam, rail, Vector3(x0, y, look.z + offset), Vector3(x1, y, look.z + offset))
	if cam.follow_z:
		for offset in [-0.06, 0.0, 0.06]:
			_append_line(cam, rail, Vector3(look.x + offset, y, z0), Vector3(look.x + offset, y, z1))
	if not rail.is_empty():
		gizmo.add_lines(rail, get_material("rail", gizmo))

	var limit_lines := PackedVector3Array()
	if cam.follow_x:
		_append_post(cam, limit_lines, Vector3(x0, y, look.z))
		_append_post(cam, limit_lines, Vector3(x1, y, look.z))
	if cam.follow_z:
		_append_post(cam, limit_lines, Vector3(look.x, y, z0))
		_append_post(cam, limit_lines, Vector3(look.x, y, z1))
	if not limit_lines.is_empty():
		gizmo.add_lines(limit_lines, get_material("limit" if cam.use_follow_limits else "rail", gizmo))

	if cam.follow_deadzone_enabled:
		var p0 := Vector3(layout.dz_min_x, y, layout.dz_min_z)
		var p1 := Vector3(layout.dz_max_x, y, layout.dz_min_z)
		var p2 := Vector3(layout.dz_max_x, y, layout.dz_max_z)
		var p3 := Vector3(layout.dz_min_x, y, layout.dz_max_z)
		var outline := PackedVector3Array()
		_append_line(cam, outline, p0, p1)
		_append_line(cam, outline, p1, p2)
		_append_line(cam, outline, p2, p3)
		_append_line(cam, outline, p3, p0)
		gizmo.add_lines(outline, get_material("deadzone", gizmo))
		var fill := _make_quad_mesh(cam, p0, p1, p2, p3)
		if fill != null:
			gizmo.add_mesh(fill, _fill_material)

	var limit_pts := PackedVector3Array()
	var limit_ids := PackedInt32Array()
	if cam.follow_x:
		limit_pts.append(cam.to_local(Vector3(x0, y + _HANDLE_HEIGHT, look.z)))
		limit_ids.append(HANDLE_LIMIT_MIN_X)
		limit_pts.append(cam.to_local(Vector3(x1, y + _HANDLE_HEIGHT, look.z)))
		limit_ids.append(HANDLE_LIMIT_MAX_X)
	if cam.follow_z:
		limit_pts.append(cam.to_local(Vector3(look.x, y + _HANDLE_HEIGHT, z0)))
		limit_ids.append(HANDLE_LIMIT_MIN_Z)
		limit_pts.append(cam.to_local(Vector3(look.x, y + _HANDLE_HEIGHT, z1)))
		limit_ids.append(HANDLE_LIMIT_MAX_Z)
	if not limit_pts.is_empty():
		gizmo.add_handles(limit_pts, get_material("handles", gizmo), limit_ids)

	if cam.follow_deadzone_enabled:
		var dead_pts := PackedVector3Array()
		var dead_ids := PackedInt32Array()
		var mid_z := (layout.dz_min_z + layout.dz_max_z) * 0.5
		var mid_x := (layout.dz_min_x + layout.dz_max_x) * 0.5
		if cam.follow_x:
			var left_x: float = layout.dz_min_x
			var right_x: float = layout.dz_max_x
			if right_x - left_x < 0.4:
				left_x = look.x - 0.35
				right_x = look.x + 0.35
			dead_pts.append(cam.to_local(Vector3(left_x, y + 0.55, mid_z)))
			dead_ids.append(HANDLE_DEAD_NEG_X)
			dead_pts.append(cam.to_local(Vector3(right_x, y + 0.55, mid_z)))
			dead_ids.append(HANDLE_DEAD_POS_X)
		if cam.follow_z:
			var back_z: float = layout.dz_min_z
			var fwd_z: float = layout.dz_max_z
			if fwd_z - back_z < 0.4:
				back_z = look.z - 0.35
				fwd_z = look.z + 0.35
			dead_pts.append(cam.to_local(Vector3(mid_x, y + 0.55, back_z)))
			dead_ids.append(HANDLE_DEAD_NEG_Z)
			dead_pts.append(cam.to_local(Vector3(mid_x, y + 0.55, fwd_z)))
			dead_ids.append(HANDLE_DEAD_POS_Z)
		if not dead_pts.is_empty():
			gizmo.add_handles(dead_pts, get_material("handles_secondary", gizmo), dead_ids, false, true)


func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	match handle_id:
		HANDLE_LIMIT_MIN_X:
			return "Follow Limit Min X"
		HANDLE_LIMIT_MAX_X:
			return "Follow Limit Max X"
		HANDLE_LIMIT_MIN_Z:
			return "Follow Limit Min Z"
		HANDLE_LIMIT_MAX_Z:
			return "Follow Limit Max Z"
		HANDLE_DEAD_NEG_X:
			return "Deadzone Left"
		HANDLE_DEAD_POS_X:
			return "Deadzone Right"
		HANDLE_DEAD_NEG_Z:
			return "Deadzone Back"
		HANDLE_DEAD_POS_Z:
			return "Deadzone Forward"
		_:
			return "ATK Camera Handle"


func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	return _snapshot(gizmo.get_node_3d())


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var cam := gizmo.get_node_3d()
	if cam == null:
		return
	var hit := _intersect_floor(camera, screen_pos, cam.gizmo_floor_y)
	if hit == null:
		return
	var world: Vector3 = hit
	match handle_id:
		HANDLE_LIMIT_MIN_X, HANDLE_LIMIT_MAX_X, HANDLE_LIMIT_MIN_Z, HANDLE_LIMIT_MAX_Z:
			_apply_limit_handle(cam, handle_id, world)
		HANDLE_DEAD_NEG_X, HANDLE_DEAD_POS_X, HANDLE_DEAD_NEG_Z, HANDLE_DEAD_POS_Z:
			_apply_deadzone_handle(cam, handle_id, world)
	cam.update_gizmos()


func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var cam := gizmo.get_node_3d()
	if cam == null or typeof(restore) != TYPE_DICTIONARY:
		return
	if cancel:
		_apply_snapshot(cam, restore)
		cam.update_gizmos()
		return
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Edit ATK camera follow handle")
	_add_snapshot_undo(ur, cam, restore)
	ur.commit_action(false)


func _apply_limit_handle(cam: Node, handle_id: int, world: Vector3) -> void:
	var layout: Dictionary = cam.get_follow_gizmo_layout()
	if not cam.use_follow_limits:
		var seeded_min: Vector3 = cam.follow_limit_min
		var seeded_max: Vector3 = cam.follow_limit_max
		seeded_min.x = layout.x0
		seeded_max.x = layout.x1
		seeded_min.z = layout.z0
		seeded_max.z = layout.z1
		cam.follow_limit_min = seeded_min
		cam.follow_limit_max = seeded_max
		cam.use_follow_limits = true
	var mn: Vector3 = cam.follow_limit_min
	var mx: Vector3 = cam.follow_limit_max
	match handle_id:
		HANDLE_LIMIT_MIN_X:
			mn.x = minf(world.x, mx.x - _MIN_LIMIT_GAP)
		HANDLE_LIMIT_MAX_X:
			mx.x = maxf(world.x, mn.x + _MIN_LIMIT_GAP)
		HANDLE_LIMIT_MIN_Z:
			mn.z = minf(world.z, mx.z - _MIN_LIMIT_GAP)
		HANDLE_LIMIT_MAX_Z:
			mx.z = maxf(world.z, mn.z + _MIN_LIMIT_GAP)
	cam.follow_limit_min = mn
	cam.follow_limit_max = mx


func _apply_deadzone_handle(cam: Node, handle_id: int, world: Vector3) -> void:
	var layout: Dictionary = cam.get_follow_gizmo_layout()
	var look: Vector3 = layout.look
	var along_x := handle_id == HANDLE_DEAD_NEG_X or handle_id == HANDLE_DEAD_POS_X
	var distance := absf(world.x - look.x) if along_x else absf(world.z - look.z)
	if distance <= _DEADZONE_SNAP:
		distance = 0.0
	if cam.follow_deadzone_mode == cam.FollowDeadzoneMode.VIEW:
		var half: Vector2 = layout.view_half
		var denom := maxf(half.x, 0.001)
		cam.follow_deadzone_view_x = clampf(distance / denom, 0.0, 0.95)
		return
	var dz: Vector3 = cam.follow_deadzone
	if along_x:
		dz.x = distance
	else:
		dz.z = distance
	cam.follow_deadzone = dz


func _snapshot(cam: Node) -> Dictionary:
	return {
		"use_follow_limits": cam.use_follow_limits,
		"follow_limit_min": cam.follow_limit_min,
		"follow_limit_max": cam.follow_limit_max,
		"follow_deadzone": cam.follow_deadzone,
		"follow_deadzone_view_x": cam.follow_deadzone_view_x,
		"follow_deadzone_view_y": cam.follow_deadzone_view_y,
	}


func _apply_snapshot(cam: Node, snap: Dictionary) -> void:
	cam.use_follow_limits = snap.use_follow_limits
	cam.follow_limit_min = snap.follow_limit_min
	cam.follow_limit_max = snap.follow_limit_max
	cam.follow_deadzone = snap.follow_deadzone
	cam.follow_deadzone_view_x = snap.follow_deadzone_view_x
	cam.follow_deadzone_view_y = snap.follow_deadzone_view_y


func _add_snapshot_undo(ur: EditorUndoRedoManager, cam: Node, snap: Dictionary) -> void:
	ur.add_do_property(cam, "use_follow_limits", cam.use_follow_limits)
	ur.add_undo_property(cam, "use_follow_limits", snap.use_follow_limits)
	ur.add_do_property(cam, "follow_limit_min", cam.follow_limit_min)
	ur.add_undo_property(cam, "follow_limit_min", snap.follow_limit_min)
	ur.add_do_property(cam, "follow_limit_max", cam.follow_limit_max)
	ur.add_undo_property(cam, "follow_limit_max", snap.follow_limit_max)
	ur.add_do_property(cam, "follow_deadzone", cam.follow_deadzone)
	ur.add_undo_property(cam, "follow_deadzone", snap.follow_deadzone)
	ur.add_do_property(cam, "follow_deadzone_view_x", cam.follow_deadzone_view_x)
	ur.add_undo_property(cam, "follow_deadzone_view_x", snap.follow_deadzone_view_x)
	ur.add_do_property(cam, "follow_deadzone_view_y", cam.follow_deadzone_view_y)
	ur.add_undo_property(cam, "follow_deadzone_view_y", snap.follow_deadzone_view_y)


func _intersect_floor(camera: Camera3D, screen_pos: Vector2, floor_y: float) -> Variant:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := (floor_y - from.y) / dir.y
	if t < 0.0:
		return null
	var point := from + dir * t
	point.y = floor_y
	return point


func _append_line(cam: Node3D, lines: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	lines.append(cam.to_local(a))
	lines.append(cam.to_local(b))


func _append_post(cam: Node3D, lines: PackedVector3Array, world_pos: Vector3) -> void:
	_append_line(cam, lines, world_pos, world_pos + Vector3(0.0, 1.8, 0.0))
	_append_line(cam, lines, world_pos + Vector3(-0.35, 0.0, 0.0), world_pos + Vector3(0.35, 0.0, 0.0))
	_append_line(cam, lines, world_pos + Vector3(0.0, 0.0, -0.35), world_pos + Vector3(0.0, 0.0, 0.35))
	var top := world_pos + Vector3(0.0, _HANDLE_HEIGHT, 0.0)
	_append_line(cam, lines, top + Vector3(-0.18, 0.0, 0.0), top + Vector3(0.18, 0.0, 0.0))
	_append_line(cam, lines, top + Vector3(0.0, 0.0, -0.18), top + Vector3(0.0, 0.0, 0.18))


func _make_quad_mesh(cam: Node3D, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := cam.to_local(p0)
	var b := cam.to_local(p1)
	var c := cam.to_local(p2)
	var d := cam.to_local(p3)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
	return st.commit()
