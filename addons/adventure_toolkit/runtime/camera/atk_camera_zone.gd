class_name ATKCameraZone
extends Area3D

## When the player (`atk_player` group) overlaps, requests the zone camera on the scene's
## `ATKCameraDirector` (Phase 13).


@export var zone_priority := 0
@export var zone_camera_path: NodePath
@export var monitor_player := true


var _director: ATKCameraDirector
var _zone_camera: Camera3D
var _player_overlap_count := 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true
	monitorable = true
	call_deferred("_bind_director_and_camera")


func _bind_director_and_camera() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_director = ATKCameraDirector.find_director(tree)
	if _director == null:
		ATKLog.warn("ATKCameraZone '%s' has no ATKCameraDirector in scene." % name, "ATKCamera")
		return
	if not zone_camera_path.is_empty():
		var n := get_node_or_null(zone_camera_path)
		if n is Camera3D:
			_zone_camera = n as Camera3D
	if _zone_camera == null:
		ATKLog.warn("ATKCameraZone '%s' has no valid zone_camera_path." % name, "ATKCamera")


func _on_body_entered(body: Node3D) -> void:
	if not monitor_player or _director == null or _zone_camera == null:
		return
	if not _is_player(body):
		return
	_player_overlap_count += 1
	if _player_overlap_count == 1:
		_director.zone_enter(self, _zone_camera, zone_priority)


func _on_body_exited(body: Node3D) -> void:
	if not monitor_player or _director == null:
		return
	if not _is_player(body):
		return
	_player_overlap_count = maxi(_player_overlap_count - 1, 0)
	if _player_overlap_count == 0:
		_director.zone_exit(self)


func _is_player(body: Node3D) -> bool:
	var n := body as Node
	return n != null and n.is_in_group("atk_player")


func _exit_tree() -> void:
	if _director != null and _player_overlap_count > 0:
		_director.zone_exit(self)
	_player_overlap_count = 0
