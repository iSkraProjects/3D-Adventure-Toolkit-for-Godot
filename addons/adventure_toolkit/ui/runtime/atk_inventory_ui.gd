extends CanvasLayer

## Default inventory UI (Phase 14 / T14.1). **Menu** (top-left) opens the pause overlay ([ATKSave] → [code]DefaultPauseOverlay[/code]).
## **Bag** (top-right) opens/closes the panel. While the panel is open (or dialogue is running), world movement is blocked.
## Optional [member keyboard_action] (Input Map) toggles the panel when [member allow_keyboard_toggle].
## Parented under [ATKInventory] autoload by default. Swap the [TextureButton] icons in the scene (or in code) when art is ready.


const _DEFAULT_TOGGLE_KEY := KEY_I

@export var allow_keyboard_toggle := true
@export var keyboard_action := "atk_toggle_inventory"
@export var start_visible := false
@export var item_definitions: Array[ATKInventoryItemDefinition] = []
@export var icon_tile_size := Vector2i(96, 96)
@export var icon_max_size := Vector2i(72, 72)
@export var grid_columns := 4

var _def_by_id: Dictionary = {}
var _tile_by_item_id: Dictionary = {}

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/Panel
@onready var _btn_pause_menu: TextureButton = $Root/PauseButton
@onready var _bag: TextureButton = $Root/BagButton
@onready var _items_scroll: ScrollContainer = $Root/Panel/Margin/VBox/ItemsScroll
@onready var _items_grid: GridContainer = $Root/Panel/Margin/VBox/ItemsScroll/ItemsGrid
@onready var _description: RichTextLabel = $Root/Panel/Margin/VBox/Description
@onready var _btn_clear: Button = $Root/Panel/Margin/VBox/Buttons/ClearButton
@onready var _btn_close: Button = $Root/Panel/Margin/VBox/Buttons/CloseButton
@onready var _selected_preview: PanelContainer = $Root/SelectedItemPreview
@onready var _selected_preview_icon: TextureRect = $Root/SelectedItemPreview/Margin/Icon


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_apply_bag_placeholder_icon()
	_apply_pause_menu_placeholder_icon()
	_panel.visible = start_visible
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if start_visible else Control.MOUSE_FILTER_IGNORE
	_btn_pause_menu.pressed.connect(_on_pause_menu_pressed)
	_bag.pressed.connect(_on_bag_pressed)

	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory == null:
		push_warning("ATKInventoryUI: ATKInventory autoload missing.")
	else:
		if item_definitions.is_empty():
			item_definitions = inventory.get_merged_item_definitions()

	_build_definition_lookup()
	_items_grid.columns = maxi(grid_columns, 1)
	_items_grid.focus_mode = Control.FOCUS_ALL
	_btn_clear.pressed.connect(_on_clear_pressed)
	_btn_close.pressed.connect(_on_close_pressed)

	if inventory == null:
		return

	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.selected_item_changed.connect(_on_selected_changed)
	_on_inventory_changed(inventory.get_all_items())
	_on_selected_changed(inventory.get_selected_item())

	if not keyboard_action.strip_edges().is_empty():
		ATKUiInputActions.ensure_action_with_default_key(keyboard_action, _DEFAULT_TOGGLE_KEY)


func _apply_bag_placeholder_icon() -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.32, 0.52, 0.82))
	var tex := ImageTexture.create_from_image(img)
	_bag.texture_normal = tex


func _apply_pause_menu_placeholder_icon() -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.22, 0.23, 0.27))
	var bar_h := 4
	var gap := 6
	var x0 := 10
	var x1 := 38
	var y := 11
	var bar_color := Color(0.92, 0.93, 0.95)
	for _i in 3:
		for yy in range(y, y + bar_h):
			for xx in range(x0, x1):
				img.set_pixel(xx, yy, bar_color)
		y += bar_h + gap
	var tex := ImageTexture.create_from_image(img)
	_btn_pause_menu.texture_normal = tex


func _on_pause_menu_pressed() -> void:
	var pause := get_node_or_null("/root/ATKSave/DefaultPauseOverlay")
	if pause != null and pause.has_method("open_pause_menu"):
		pause.call("open_pause_menu")


func _on_bag_pressed() -> void:
	_set_panel_open(not _panel.visible)


func is_inventory_panel_open() -> bool:
	return _panel.visible


## Shows or hides the bag, menu button, and full layer. When hiding (e.g. main menu), the inventory panel is closed.
func set_hud_layer_visible(on: bool) -> void:
	visible = on
	if not on:
		_set_panel_open(false)


func _set_panel_open(open: bool) -> void:
	_panel.visible = open
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open:
		_items_grid.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if not allow_keyboard_toggle:
		return
	if not _keyboard_shortcuts_allowed():
		return
	if keyboard_action.strip_edges().is_empty():
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not Input.is_action_just_pressed(StringName(keyboard_action)):
		return
	_set_panel_open(not _panel.visible)
	get_viewport().set_input_as_handled()


func _keyboard_shortcuts_allowed() -> bool:
	var settings := get_node_or_null("/root/ATKSettings")
	if settings == null or not settings.has_method("is_keyboard_shortcuts_enabled"):
		return true
	return bool(settings.call("is_keyboard_shortcuts_enabled"))


func _build_definition_lookup() -> void:
	_def_by_id.clear()
	for def in item_definitions:
		if def == null or def.item_id.is_empty():
			continue
		_def_by_id[def.item_id] = def


func _on_inventory_changed(items: Dictionary) -> void:
	_clear_item_tiles()
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory == null:
		return

	var keys: Array = items.keys()
	keys.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)

	for k in keys:
		var item_id := str(k)
		var amount := int(items[k])
		var icon := _resolve_item_icon(inventory, item_id)
		_add_item_tile(item_id, amount, icon)

	_sync_selection_highlight(inventory.get_selected_item())


func _on_selected_changed(item_id: String) -> void:
	_sync_selection_highlight(item_id)
	_refresh_description(item_id)
	_refresh_selected_preview(item_id)


func _apply_selection_item_id(item_id: String) -> void:
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory == null:
		return
	if item_id.is_empty():
		return
	inventory.select_item(item_id)
	_set_panel_open(false)


func _on_clear_pressed() -> void:
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory != null and inventory.has_method("clear_selected_item"):
		inventory.clear_selected_item()


func _on_close_pressed() -> void:
	_set_panel_open(false)


func _sync_selection_highlight(selected_id: String) -> void:
	for item_id in _tile_by_item_id.keys():
		var tile: Button = _tile_by_item_id[item_id]
		if tile == null:
			continue
		var selected := (str(item_id) == selected_id)
		tile.button_pressed = selected
		_apply_tile_selection_visual(tile, selected)


func _refresh_description(item_id: String) -> void:
	if item_id.is_empty():
		_description.text = "[i]No item selected.[/i]"
		return
	if _def_by_id.has(item_id):
		var def: ATKInventoryItemDefinition = _def_by_id[item_id]
		var title := def.display_name if not def.display_name.is_empty() else item_id
		var body := def.description.strip_edges()
		if body.is_empty():
			body = "[i]No description.[/i]"
		_description.text = "[b]%s[/b]\n%s" % [title, body]
	else:
		_description.text = "[b]%s[/b]\n[i]No item definition linked in ATKInventoryUI.[/i]" % item_id


func _display_name(item_id: String) -> String:
	if _def_by_id.has(item_id):
		var def: ATKInventoryItemDefinition = _def_by_id[item_id]
		if not def.display_name.strip_edges().is_empty():
			return def.display_name.strip_edges()
	return item_id


func _resolve_item_icon(inventory: Node, item_id: String) -> Texture2D:
	if inventory != null and inventory.has_method("get_item_icon"):
		var icon_value: Variant = inventory.call("get_item_icon", item_id)
		if icon_value is Texture2D:
			return icon_value as Texture2D
	if _def_by_id.has(item_id):
		var def: ATKInventoryItemDefinition = _def_by_id[item_id]
		if def != null and def.icon != null:
			return def.icon
	return null


func _clear_item_tiles() -> void:
	for child in _items_grid.get_children():
		child.queue_free()
	_tile_by_item_id.clear()


func _add_item_tile(item_id: String, amount: int, icon: Texture2D) -> void:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.custom_minimum_size = Vector2(icon_tile_size.x, icon_tile_size.y)
	tile.flat = false
	tile.text = ""
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.clip_text = true
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.tooltip_text = _display_name(item_id)
	_apply_tile_selection_visual(tile, false)
	tile.pressed.connect(func() -> void:
		_apply_selection_item_id(item_id)
	)
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				_inspect_item(item_id)
				get_viewport().set_input_as_handled()
	)

	var icon_holder := MarginContainer.new()
	icon_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	icon_holder.offset_left = 8
	icon_holder.offset_top = 6
	icon_holder.offset_right = -8
	icon_holder.offset_bottom = 6 + icon_max_size.y
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon_holder)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(icon_max_size.x, icon_max_size.y)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = icon
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon_rect)

	if amount > 1:
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -34
		badge.offset_top = 4
		badge.offset_right = -4
		badge.offset_bottom = 24
		var badge_bg := StyleBoxFlat.new()
		badge_bg.bg_color = Color(0.1, 0.1, 0.12, 0.95)
		badge_bg.set_corner_radius_all(4)
		badge.add_theme_stylebox_override("panel", badge_bg)
		var badge_text := Label.new()
		badge_text.text = "x%d" % amount
		badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_text.add_theme_font_size_override("font_size", 12)
		badge_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		badge.add_child(badge_text)
		tile.add_child(badge)

	_items_grid.add_child(tile)
	_tile_by_item_id[item_id] = tile


func _apply_tile_selection_visual(tile: Button, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 0.9)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_top = 6
	sb.content_margin_right = 6
	sb.content_margin_bottom = 6
	if selected:
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.35, 0.75, 1.0, 1.0)
		sb.shadow_color = Color(0.2, 0.6, 1.0, 0.35)
		sb.shadow_size = 4
	else:
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.25, 0.27, 0.32, 0.8)
		sb.shadow_size = 0
	tile.add_theme_stylebox_override("normal", sb)
	tile.add_theme_stylebox_override("hover", sb)
	tile.add_theme_stylebox_override("pressed", sb)


func _inspect_item(item_id: String) -> void:
	_refresh_description(item_id)
	var title := _display_name(item_id)
	var body := ""
	if _def_by_id.has(item_id):
		var def: ATKInventoryItemDefinition = _def_by_id[item_id]
		body = def.description.strip_edges()
	if body.is_empty():
		body = "No description."
	var bus := get_node_or_null("/root/ATKInteractionFeedback")
	if bus != null and bus.has_method("show_message"):
		bus.call("show_message", body, title, item_id)


func _refresh_selected_preview(item_id: String) -> void:
	if _selected_preview == null or _selected_preview_icon == null:
		return
	if item_id.is_empty():
		_selected_preview.visible = false
		_selected_preview_icon.texture = null
		_selected_preview.tooltip_text = ""
		return
	var inventory := get_node_or_null("/root/ATKInventory")
	var icon := _resolve_item_icon(inventory, item_id)
	_selected_preview_icon.texture = icon
	_selected_preview.visible = icon != null
	_selected_preview.tooltip_text = _display_name(item_id)
