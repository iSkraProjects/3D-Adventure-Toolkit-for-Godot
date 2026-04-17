extends ATKDoor

## Demo: locked crate opened with the brass key ([member required_item_id]). Shows a lid mesh until open, then reveals the ball pickup.

const KEY_OPEN := "door_open"

@export_multiline var opened_feedback := "The key opened the crate and there is a ball inside."

@onready var _lid: MeshInstance3D = $Body/LidMesh
@onready var _crate_collision: CollisionShape3D = $Body/CollisionShape3D
@onready var _ball: ATKPickup = $BallPickup

var _had_open_state := false


func _ready() -> void:
	super._ready()
	_had_open_state = is_open
	_apply_crate_visuals()
	var st := get_node_or_null("/root/ATKState")
	if st != null:
		st.object_changed.connect(_on_object_state_changed)


func _on_object_state_changed(object_id: String, key: String, value: Variant, _old_value: Variant) -> void:
	if object_id != self.object_id:
		return
	if str(key) != KEY_OPEN:
		return
	is_open = bool(value)
	_apply_crate_visuals()


func _apply_crate_visuals() -> void:
	if _lid != null:
		_lid.visible = not is_open
	## When open, disable the crate hull so raycasts reach the ball pickup inside / in front of the mesh.
	if _crate_collision != null:
		_crate_collision.disabled = is_open
	if _ball != null:
		if is_open:
			_ball.set_runtime_visible(true)
			_ball.set_runtime_interactable(true)
		else:
			_ball.set_runtime_visible(false)
			_ball.set_runtime_interactable(false)

	if is_open and not _had_open_state:
		var msg := opened_feedback.strip_edges()
		if not msg.is_empty():
			_push_interaction_message(msg)
	_had_open_state = is_open


func get_hover_tooltip_secondary() -> String:
	if is_open and _ball != null and is_instance_valid(_ball):
		var nm := _ball.display_name.strip_edges()
		if nm.is_empty():
			nm = _ball.item_id
		if not nm.is_empty():
			return "Contains: %s" % nm
	return super.get_hover_tooltip_secondary()
