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
@export var cursor_theme: ATKCursorTheme
@export_file("*.tres", "*.res") var default_cursor_theme_path := "res://addons/adventure_toolkit/resources/cursors/default_cursor_theme.tres"
@export var default_cursor_interact_path := "res://addons/adventure_toolkit/resources/cursors/cursor_interact.png"
@export var default_cursor_inspect_path := "res://addons/adventure_toolkit/resources/cursors/cursor_inspect.png"
@export var default_cursor_normal_path := "res://addons/adventure_toolkit/resources/cursors/cursor_normal.png"
@export var default_cursor_open_path := "res://addons/adventure_toolkit/resources/cursors/cursor_open.png"
@export var default_cursor_attack_path := "res://addons/adventure_toolkit/resources/cursors/cursor_attack.png"
@export var default_cursor_climb_path := "res://addons/adventure_toolkit/resources/cursors/cursor_climb.png"
@export var default_cursor_descend_path := "res://addons/adventure_toolkit/resources/cursors/cursor_descend.png"
@export var debug_cursor_tracing := false

var _root_ui: Control
var _panel: PanelContainer
var _primary: Label
var _secondary: Label
var _current_cursor_kind := "normal"
var _runtime_cursor_normal: Texture2D
var _runtime_cursor_interact: Texture2D
var _runtime_cursor_inspect: Texture2D
var _runtime_cursor_open: Texture2D
var _runtime_cursor_attack: Texture2D
var _runtime_cursor_climb: Texture2D
var _runtime_cursor_descend: Texture2D
var _active_cursor_texture: Texture2D
var _last_debug_reason := ""
var _last_debug_shape := -1


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
	_apply_cursor_kind("normal")


func _process(_delta: float) -> void:
	if not enabled:
		_debug_reason("disabled")
		_apply_cursor_kind("normal")
		_hide()
		return

	var w := get_node_or_null("/root/ATKWorldUi")
	if w != null and w.has_method("is_world_interaction_locked") and bool(w.call("is_world_interaction_locked")):
		_debug_reason("world_ui_locked")
		_apply_cursor_kind("normal")
		_hide()
		return

	var viewport := get_viewport()
	if viewport == null:
		_debug_reason("no_viewport")
		_apply_cursor_kind("normal")
		_hide()
		return

	var mouse := viewport.get_mouse_position()
	var obj := ATKInteractionPointer.adventure_object_from_screen_pos(mouse, viewport, [])
	if obj == null or not obj.can_interact():
		_debug_reason("no_interactable_under_cursor")
		_apply_cursor_kind("normal")
		_hide()
		return

	if cursor_feedback_enabled:
		var cursor_kind := "interact"
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			cursor_kind = "inspect"
		elif obj.has_method("get_hover_cursor_kind"):
			cursor_kind = str(obj.call("get_hover_cursor_kind")).strip_edges().to_lower()
			if cursor_kind.is_empty():
				cursor_kind = "interact"
		_debug_reason("hovering_%s:%s" % [_debug_object_label(obj), cursor_kind])
		_apply_cursor_kind(cursor_kind)

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


func _apply_cursor_kind(kind: String) -> void:
	if not cursor_feedback_enabled:
		_debug_reason("cursor_feedback_disabled")
		return

	var desired_kind := kind
	var desired_texture := _resolve_runtime_cursor_texture(desired_kind)
	if desired_texture == null and desired_kind != "normal":
		desired_kind = "interact"
		desired_texture = _resolve_runtime_cursor_texture(desired_kind)
	if desired_texture == null:
		desired_kind = "normal"
		desired_texture = _resolve_runtime_cursor_texture(desired_kind)

	# Force reliability on Windows/export: always drive arrow cursor texture directly.
	# Many UI controls override cursor shape, so we keep default shape at ARROW and swap texture.
	if _current_cursor_kind == desired_kind and _active_cursor_texture == desired_texture and Input.get_current_cursor_shape() == Input.CURSOR_ARROW:
		return
	_current_cursor_kind = desired_kind
	_active_cursor_texture = desired_texture
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(
		desired_texture,
		Input.CURSOR_ARROW,
		_resolve_hotspot(desired_kind) if desired_texture != null else Vector2.ZERO
	)
	_debug_shape(desired_kind, desired_texture != null)


func _prepare_runtime_cursors() -> void:
	var theme := _resolve_cursor_theme()
	if theme != null:
		_runtime_cursor_normal = theme.get_texture("normal")
		_runtime_cursor_interact = theme.get_texture("interact")
		_runtime_cursor_inspect = theme.get_texture("inspect")
		_runtime_cursor_open = theme.get_texture("open")
		_runtime_cursor_attack = theme.get_texture("attack")
		_runtime_cursor_climb = theme.get_texture("climb")
		_runtime_cursor_descend = theme.get_texture("descend")

	if _runtime_cursor_normal == null:
		_runtime_cursor_normal = _load_cursor_texture(default_cursor_normal_path)
	var from_file_interact := _load_cursor_texture(default_cursor_interact_path)
	var from_file_inspect := _load_cursor_texture(default_cursor_inspect_path)
	var from_file_open := _load_cursor_texture(default_cursor_open_path)
	var from_file_attack := _load_cursor_texture(default_cursor_attack_path)
	var from_file_climb := _load_cursor_texture(default_cursor_climb_path)
	var from_file_descend := _load_cursor_texture(default_cursor_descend_path)
	_runtime_cursor_interact = custom_cursor_interact if custom_cursor_interact != null else (_runtime_cursor_interact if _runtime_cursor_interact != null else (
		from_file_interact if from_file_interact != null else _build_interact_cursor_texture()
	))
	_runtime_cursor_inspect = custom_cursor_inspect if custom_cursor_inspect != null else (_runtime_cursor_inspect if _runtime_cursor_inspect != null else (
		from_file_inspect if from_file_inspect != null else _build_inspect_cursor_texture()
	))
	_runtime_cursor_open = _runtime_cursor_open if _runtime_cursor_open != null else from_file_open
	_runtime_cursor_attack = _runtime_cursor_attack if _runtime_cursor_attack != null else from_file_attack
	_runtime_cursor_climb = _runtime_cursor_climb if _runtime_cursor_climb != null else from_file_climb
	_runtime_cursor_descend = _runtime_cursor_descend if _runtime_cursor_descend != null else from_file_descend
	if _runtime_cursor_normal == null:
		_runtime_cursor_normal = _runtime_cursor_interact

	# Register secondary shape slots as backup paths.
	Input.set_custom_mouse_cursor(_runtime_cursor_interact, Input.CURSOR_POINTING_HAND, _resolve_hotspot("interact"))
	Input.set_custom_mouse_cursor(_runtime_cursor_inspect, Input.CURSOR_HELP, _resolve_hotspot("inspect"))


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


func _load_cursor_texture(path: String) -> Texture2D:
	var p := path.strip_edges()
	if p.is_empty():
		return null
	if not ResourceLoader.exists(p):
		return null
	var loaded := load(p)
	if loaded is Texture2D:
		return loaded as Texture2D
	return null


func _debug_reason(reason: String) -> void:
	if not debug_cursor_tracing:
		return
	if _last_debug_reason == reason:
		return
	_last_debug_reason = reason
	ATKLog.info("[cursor] %s" % reason, "ATKInteractionHover")


func _debug_shape(kind: String, has_texture: bool) -> void:
	if not debug_cursor_tracing:
		return
	var signature := hash("%s|%s" % [kind, str(has_texture)])
	if _last_debug_shape == signature:
		return
	_last_debug_shape = signature
	ATKLog.info("[cursor] apply kind=%s texture=%s" % [kind, str(has_texture)], "ATKInteractionHover")


func _debug_object_label(obj: ATKAdventureObject) -> String:
	if obj == null:
		return "null"
	var oid := obj.object_id.strip_edges()
	if not oid.is_empty():
		return oid
	return obj.name


func _resolve_cursor_theme() -> ATKCursorTheme:
	if cursor_theme != null:
		return cursor_theme
	var p := default_cursor_theme_path.strip_edges()
	if p.is_empty():
		return null
	if not ResourceLoader.exists(p):
		return null
	var loaded := load(p)
	if loaded is ATKCursorTheme:
		return loaded as ATKCursorTheme
	return null


func _resolve_runtime_cursor_texture(kind: String) -> Texture2D:
	match kind:
		"interact":
			return _runtime_cursor_interact
		"inspect":
			return _runtime_cursor_inspect
		"open":
			return _runtime_cursor_open
		"attack":
			return _runtime_cursor_attack
		"climb":
			return _runtime_cursor_climb
		"descend":
			return _runtime_cursor_descend
		_:
			return _runtime_cursor_normal


func _resolve_hotspot(kind: String) -> Vector2:
	var theme := _resolve_cursor_theme()
	if theme != null:
		return theme.get_hotspot(kind)
	return custom_cursor_hotspot
