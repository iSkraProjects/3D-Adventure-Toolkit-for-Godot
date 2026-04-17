class_name ATKCameraDirector
extends Node

## One per scene (add to group `atk_camera_director`). Picks the active `Camera3D` from
## zone priorities and optional temporary overrides (Phase 13).
## For interaction framing, connect to `ATKPlayerController.interaction_started` / `interaction_finished`
## and call `request_interaction_camera` / `release_interaction_camera` with the token returned.


signal active_camera_changed(camera: Camera3D)
signal override_pushed(token: int, camera: Camera3D, priority: int)
signal override_popped(token: int)


@export var default_camera_path: NodePath

var _default_camera: Camera3D
var _current_camera: Camera3D

var _active_zones: Dictionary = {} # Node -> { "camera": Camera3D, "priority": int }
var _override_tokens: Dictionary = {} # int -> { "camera": Camera3D, "priority": int }
var _next_token := 1


func _ready() -> void:
	add_to_group("atk_camera_director")
	if Engine.is_editor_hint():
		return
	call_deferred("_resolve_default_camera")
	call_deferred("_recompute_active_camera")


static func find_director(tree: SceneTree) -> ATKCameraDirector:
	if tree == null:
		return null
	return tree.get_first_node_in_group("atk_camera_director") as ATKCameraDirector


## Temporary camera (interactions, dialogue, cutscenes). Returns token for `pop_camera_override`.
func push_camera_override(camera: Camera3D, priority: int = 50) -> int:
	if camera == null:
		return -1
	var token := _next_token
	_next_token += 1
	_override_tokens[token] = {"camera": camera, "priority": priority}
	emit_signal("override_pushed", token, camera, priority)
	ATKLog.debug("Camera override push token=%d prio=%d" % [token, priority], "ATKCamera")
	_recompute_active_camera()
	return token


func pop_camera_override(token: int) -> void:
	if not _override_tokens.has(token):
		return
	_override_tokens.erase(token)
	emit_signal("override_popped", token)
	ATKLog.debug("Camera override pop token=%d" % token, "ATKCamera")
	_recompute_active_camera()


## Alias for gameplay code readability (T13.2).
func request_interaction_camera(camera: Camera3D, priority: int = 50) -> int:
	return push_camera_override(camera, priority)


func release_interaction_camera(token: int) -> void:
	pop_camera_override(token)


func zone_enter(zone: Node, camera: Camera3D, priority: int) -> void:
	if zone == null or camera == null:
		return
	_active_zones[zone] = {"camera": camera, "priority": priority}
	_recompute_active_camera()


func zone_exit(zone: Node) -> void:
	if zone == null:
		return
	_active_zones.erase(zone)
	_recompute_active_camera()


func _resolve_default_camera() -> void:
	if not default_camera_path.is_empty():
		var n := get_node_or_null(default_camera_path)
		if n is Camera3D:
			_default_camera = n as Camera3D
	if _default_camera == null:
		_default_camera = _find_first_camera_in_tree()


func _find_first_camera_in_tree() -> Camera3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for c in scene.find_children("*", "Camera3D", true, false):
		if c is Camera3D:
			return c as Camera3D
	return null


func _recompute_active_camera() -> void:
	var best: Camera3D = null
	var best_p := -999999999

	for token in _override_tokens.keys():
		var e: Dictionary = _override_tokens[token]
		var p := int(e.get("priority", 0))
		var cam: Variant = e.get("camera", null)
		if cam is Camera3D and p > best_p:
			best_p = p
			best = cam as Camera3D

	if best == null:
		for z in _active_zones.keys():
			var ze: Dictionary = _active_zones[z]
			var zp := int(ze.get("priority", 0))
			var zc: Variant = ze.get("camera", null)
			if zc is Camera3D and zp > best_p:
				best_p = zp
				best = zc as Camera3D

	if best == null:
		best = _default_camera

	_apply_camera_current(best)


func _apply_camera_current(next: Camera3D) -> void:
	if next == null and _default_camera == null:
		ATKLog.warn("ATKCameraDirector: no active or default Camera3D.", "ATKCamera")
	if _current_camera != null and is_instance_valid(_current_camera):
		_current_camera.current = false
	_current_camera = next
	if next != null and is_instance_valid(next):
		next.current = true
		emit_signal("active_camera_changed", next)
	else:
		emit_signal("active_camera_changed", null)
