extends CanvasLayer

## Shows a small nameplate when the mouse points at an [ATKAdventureObject] that [method ATKAdventureObject.can_interact] allows.
## Text comes from [method ATKAdventureObject.get_hover_tooltip_primary] / [method ATKAdventureObject.get_hover_tooltip_secondary].
## Disabled while [ATKWorldUi.is_world_interaction_locked] is true.


@export var enabled := true
@export var canvas_layer := 18
## Extra pixels above the projected anchor (screen space).
@export var screen_offset := Vector2(0, -10)
@export var edge_margin := 8.0
## Cursor feedback: when true, hovering an interactable changes cursor.
@export var cursor_feedback_enabled := true
## Optional custom cursor textures. If unset, Godot cursor shapes are used.
@export var custom_cursor_interact: Texture2D
@export var custom_cursor_inspect: Texture2D
@export var custom_cursor_hotspot := Vector2.ZERO

var _root_ui: Control
var _panel: PanelContainer
var _primary: Label
var _secondary: Label
var _current_cursor_shape := Input.CURSOR_ARROW
var _runtime_cursor_interact: Texture2D
var _runtime_cursor_inspect: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = canvas_layer

	_root_ui = Control.new()
	_root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_ui)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ui.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	_primary = Label.new()
	_primary.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_primary)

	_secondary = Label.new()
	_secondary.add_theme_font_size_override("font_size", 13)
	_secondary.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	vbox.add_child(_secondary)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.82)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 0
	sb.content_margin_top = 0
	sb.content_margin_right = 0
	sb.content_margin_bottom = 0
	_panel.add_theme_stylebox_override("panel", sb)

	_prepare_runtime_cursors()
	_apply_cursor_shape(Input.CURSOR_ARROW)


func _process(_delta: float) -> void:
	if not enabled:
		_apply_cursor_shape(Input.CURSOR_ARROW)
		_hide()
		return

	var w := get_node_or_null("/root/ATKWorldUi")
	if w != null and w.has_method("is_world_interaction_locked") and bool(w.call("is_world_interaction_locked")):
		_apply_cursor_shape(Input.CURSOR_ARROW)
		_hide()
		return

	var viewport := get_viewport()
	if viewport == null:
		_apply_cursor_shape(Input.CURSOR_ARROW)
		_hide()
		return

	var mouse := viewport.get_mouse_position()
	var obj := ATKInteractionPointer.adventure_object_from_screen_pos(mouse, viewport, [])
	if obj == null or not obj.can_interact():
		_apply_cursor_shape(Input.CURSOR_ARROW)
		_hide()
		return

	# Right-click context while hovering an object: show inspect cursor.
	if cursor_feedback_enabled:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_apply_cursor_shape(Input.CURSOR_HELP)
		else:
			_apply_cursor_shape(Input.CURSOR_POINTING_HAND)

	var primary := obj.get_hover_tooltip_primary().strip_edges()
	if primary.is_empty():
		_hide()
		return

	var secondary := obj.get_hover_tooltip_secondary().strip_edges()

	_primary.text = primary
	_secondary.visible = not secondary.is_empty()
	_secondary.text = secondary

	var camera := viewport.get_camera_3d()
	if camera == null:
		_hide()
		return

	var world_pos := obj.get_hover_tooltip_world_position()
	var to_p := world_pos - camera.global_position
	if to_p.length_squared() < 0.0001:
		_hide()
		return
	var forward := -camera.global_transform.basis.z.normalized()
	if to_p.normalized().dot(forward) < 0.02:
		_hide()
		return

	var sp := camera.unproject_position(world_pos) + screen_offset
	_panel.visible = true
	_panel.reset_size()

	var size := _panel.get_rect().size
	var vp_size := viewport.get_visible_rect().size
	var pos := sp - Vector2(size.x * 0.5, size.y + 4.0)
	pos.x = clampf(pos.x, edge_margin, maxf(edge_margin, vp_size.x - size.x - edge_margin))
	pos.y = clampf(pos.y, edge_margin, maxf(edge_margin, vp_size.y - size.y - edge_margin))
	_panel.position = pos


func _hide() -> void:
	if _panel != null:
		_panel.visible = false


func _apply_cursor_shape(shape: int) -> void:
	if not cursor_feedback_enabled:
		return
	# Re-apply when needed: other UI controls can override cursor shape.
	if _current_cursor_shape == shape and Input.get_current_cursor_shape() == shape:
		return
	_current_cursor_shape = shape
	Input.set_default_cursor_shape(shape)


func _prepare_runtime_cursors() -> void:
	_runtime_cursor_interact = custom_cursor_interact if custom_cursor_interact != null else _build_interact_cursor_texture()
	_runtime_cursor_inspect = custom_cursor_inspect if custom_cursor_inspect != null else _build_inspect_cursor_texture()
	Input.set_custom_mouse_cursor(_runtime_cursor_interact, Input.CURSOR_POINTING_HAND, custom_cursor_hotspot)
	Input.set_custom_mouse_cursor(_runtime_cursor_inspect, Input.CURSOR_HELP, custom_cursor_hotspot)


func _build_interact_cursor_texture() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# bright hand-like pointer triangle + stem
	for y in range(3, 19):
		var x_end := mini(5 + y / 2, 13)
		for x in range(3, x_end):
			img.set_pixel(x, y, Color(0.95, 0.95, 0.95, 1.0))
	for y in range(12, 21):
		for x in range(10, 14):
			img.set_pixel(x, y, Color(0.95, 0.95, 0.95, 1.0))
	return ImageTexture.create_from_image(img)


func _build_inspect_cursor_texture() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# magnifier ring
	var center := Vector2(9, 9)
	for y in range(2, 17):
		for x in range(2, 17):
			var d := Vector2(x, y).distance_to(center)
			if d >= 4.0 and d <= 6.0:
				img.set_pixel(x, y, Color(0.95, 0.95, 0.95, 1.0))
	# handle
	for i in range(0, 8):
		var px := 13 + i
		var py := 13 + i
		if px < 24 and py < 24:
			img.set_pixel(px, py, Color(0.95, 0.95, 0.95, 1.0))
			if px + 1 < 24:
				img.set_pixel(px + 1, py, Color(0.95, 0.95, 0.95, 1.0))
	return ImageTexture.create_from_image(img)
