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

var _def_by_id: Dictionary = {}

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/Panel
@onready var _btn_pause_menu: TextureButton = $Root/PauseButton
@onready var _bag: TextureButton = $Root/BagButton
@onready var _item_list: ItemList = $Root/Panel/Margin/VBox/ItemList
@onready var _description: RichTextLabel = $Root/Panel/Margin/VBox/Description
@onready var _btn_clear: Button = $Root/Panel/Margin/VBox/Buttons/ClearButton
@onready var _btn_close: Button = $Root/Panel/Margin/VBox/Buttons/CloseButton


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
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_clicked.connect(_on_item_clicked)
	_item_list.item_activated.connect(_on_item_activated)
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
		_item_list.call_deferred("grab_focus")


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
	_item_list.clear()
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory == null:
		return

	var keys: Array = items.keys()
	keys.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)

	for k in keys:
		var item_id := str(k)
		var amount := int(items[k])
		var label := "%s  ×%d" % [_display_name(item_id), amount]
		var idx := _item_list.add_item(label)
		_item_list.set_item_metadata(idx, item_id)

	_sync_selection_highlight(inventory.get_selected_item())


func _on_selected_changed(item_id: String) -> void:
	_sync_selection_highlight(item_id)
	_refresh_description(item_id)


func _on_item_selected(index: int) -> void:
	_apply_selection_index(index)


func _on_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_apply_selection_index(index)


func _on_item_activated(index: int) -> void:
	_apply_selection_index(index)


func _apply_selection_index(index: int) -> void:
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory == null:
		return
	if index < 0 or index >= _item_list.item_count:
		return
	var item_id := str(_item_list.get_item_metadata(index))
	inventory.select_item(item_id)


func _on_clear_pressed() -> void:
	var inventory := get_node_or_null("/root/ATKInventory")
	if inventory != null and inventory.has_method("clear_selected_item"):
		inventory.clear_selected_item()


func _on_close_pressed() -> void:
	_set_panel_open(false)


func _sync_selection_highlight(selected_id: String) -> void:
	_item_list.deselect_all()
	if selected_id.is_empty():
		return
	for i in range(_item_list.item_count):
		if str(_item_list.get_item_metadata(i)) == selected_id:
			_item_list.select(i)
			return


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
