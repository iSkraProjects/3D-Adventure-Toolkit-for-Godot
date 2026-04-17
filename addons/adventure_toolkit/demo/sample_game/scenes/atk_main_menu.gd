extends CanvasLayer

## Phase 15 entry: main menu → **New Game** (fresh scene load), **Continue** (first matching save in
## [member continue_slot_preference]), or **Load game…** (pick any slot in the save / load panel).
## Registers [member game_scene_id] with [ATKScenes] on startup so loads can resolve saves.
## Optional [member splash_hold_seconds] for a simple black splash (T15.3 stub).


@export var game_title := "AGToolkit"
@export var game_scene_id := "scene_test_adventure"
@export_file("*.tscn") var game_scene_path := "res://Scenes/test_adventure.tscn"
@export var start_spawn_id := "spawn_entry"
## Tried in order until one has a save file (T15.2 continue).
@export var continue_slot_preference: PackedStringArray = PackedStringArray(["slot_1", "slot_2", "slot_3"])
## If greater than zero, shows a black full-screen splash this many seconds before the menu (T15.3 minimal pipeline).
@export var splash_hold_seconds := 0.0

@onready var _splash: ColorRect = $Splash
@onready var _menu_root: Control = $MenuRoot
@onready var _title: Label = $MenuRoot/Center/Panel/Margin/VBox/Title
@onready var _btn_new: Button = $MenuRoot/Center/Panel/Margin/VBox/NewGameButton
@onready var _btn_continue: Button = $MenuRoot/Center/Panel/Margin/VBox/ContinueButton
@onready var _btn_load_game: Button = $MenuRoot/Center/Panel/Margin/VBox/LoadGameButton
@onready var _btn_options: Button = $MenuRoot/Center/Panel/Margin/VBox/OptionsButton
@onready var _btn_quit: Button = $MenuRoot/Center/Panel/Margin/VBox/QuitButton
var _options_menu: ATKOptionsMenu


func _enter_tree() -> void:
	## Autoload gameplay HUD can stay visible across scene changes; hide after this node is attached.
	call_deferred("_set_inventory_ui_visible", false)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	# Sit above other toolkit CanvasLayers (dialogue 25, save 29, etc.) so the menu always receives clicks.
	layer = 100
	print("[ATKMainMenu] _ready: layer=%d paused=%s" % [layer, get_tree().paused])
	_ensure_game_registered()
	_set_inventory_ui_visible(false)
	_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = game_title
	_ensure_options_controls()
	_btn_new.pressed.connect(_on_new_game_pressed)
	_btn_continue.pressed.connect(_on_continue_pressed)
	_btn_load_game.pressed.connect(_on_load_game_pressed)
	_btn_options.pressed.connect(_on_options_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)
	_menu_root.gui_input.connect(_on_menu_root_gui_input)
	_btn_new.gui_input.connect(_on_new_gui_input)
	_btn_continue.gui_input.connect(_on_continue_gui_input)
	_btn_quit.gui_input.connect(_on_quit_gui_input)
	_btn_new.button_down.connect(func() -> void: print("[ATKMainMenu] NewGame button_down"))
	_btn_continue.button_down.connect(func() -> void: print("[ATKMainMenu] Continue button_down"))
	_btn_quit.button_down.connect(func() -> void: print("[ATKMainMenu] Quit button_down"))

	var atk_save := get_node_or_null("/root/ATKSave")
	if atk_save != null and atk_save.has_signal("delete_finished"):
		atk_save.delete_finished.connect(_on_atk_save_delete_finished)

	if splash_hold_seconds > 0.001:
		_splash.visible = true
		_menu_root.visible = false
		await get_tree().create_timer(splash_hold_seconds).timeout
	_splash.visible = false
	_menu_root.visible = true
	_update_continue_state()
	print(
		"[ATKMainMenu] buttons ready: New rect=%s Continue rect=%s Load rect=%s Quit rect=%s"
		% [
			_btn_new.get_global_rect(),
			_btn_continue.get_global_rect(),
			_btn_load_game.get_global_rect(),
			_btn_quit.get_global_rect(),
		]
	)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[ATKMainMenu] _input: button=%s pos=%s" % [event.button_index, event.position])


func _on_menu_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[ATKMainMenu] MenuRoot gui_input: button=%s pos=%s" % [event.button_index, event.position])


func _on_new_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[ATKMainMenu] NewGame gui_input: button=%s pos=%s" % [event.button_index, event.position])


func _on_continue_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[ATKMainMenu] Continue gui_input: button=%s pos=%s" % [event.button_index, event.position])


func _on_quit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[ATKMainMenu] Quit gui_input: button=%s pos=%s" % [event.button_index, event.position])


func _ensure_game_registered() -> void:
	var mgr := get_node_or_null("/root/ATKScenes")
	if mgr == null:
		push_error("ATKMainMenu: ATKScenes autoload missing.")
		return
	mgr.register_scene(game_scene_id, game_scene_path)
	mgr.register_scene("scene_demo_finale", "res://Scenes/demo_scene_finale.tscn")


func _find_continue_slot() -> String:
	for slot_id in continue_slot_preference:
		var s := str(slot_id).strip_edges()
		if s.is_empty():
			continue
		if ATKSave.has_slot(s):
			return s
	return ""


func _update_continue_state() -> void:
	var slot := _find_continue_slot()
	var has_save := not slot.is_empty()
	_btn_continue.disabled = not has_save
	_btn_load_game.disabled = not has_save
	var tip := "" if has_save else "No save in slot_1–slot_3."
	_btn_continue.tooltip_text = tip
	_btn_load_game.tooltip_text = tip


func _on_atk_save_delete_finished(_slot_id: String, success: bool, _message: String) -> void:
	if success:
		_update_continue_state()


func _on_new_game_pressed() -> void:
	print("[ATKMainMenu] New Game pressed → loading scene…")
	_set_inventory_ui_visible(true)
	_ensure_game_registered()
	var mgr := get_node_or_null("/root/ATKScenes")
	if mgr == null:
		return
	var err: Error = await mgr.load_scene(game_scene_id, start_spawn_id)
	if err != OK:
		push_warning("ATKMainMenu: New game load failed (%d)." % err)


func _on_continue_pressed() -> void:
	var slot := _find_continue_slot()
	if slot.is_empty():
		print("[ATKMainMenu] Continue pressed but no save slot — ignored.")
		return
	print("[ATKMainMenu] Continue pressed → slot=%s" % slot)
	_set_inventory_ui_visible(true)
	_ensure_game_registered()
	var ok: bool = await ATKSave.load_slot_and_restore(slot)
	if not ok:
		push_warning("ATKMainMenu: Continue load/restore failed for '%s'." % slot)


func _on_load_game_pressed() -> void:
	if _find_continue_slot().is_empty():
		return
	_ensure_game_registered()
	var save_ui := get_node_or_null("/root/ATKSave/DefaultSaveUI")
	if save_ui == null:
		push_warning("ATKMainMenu: DefaultSaveUI missing.")
		return
	if save_ui.has_method("open_above_canvas"):
		save_ui.open_above_canvas(self)
	else:
		save_ui.layer = layer + 1
		save_ui.visible = true
		if save_ui.has_method("refresh_panel"):
			save_ui.call("refresh_panel")


func _on_quit_pressed() -> void:
	print("[ATKMainMenu] Quit pressed.")
	get_tree().quit()


func _on_options_pressed() -> void:
	if _options_menu == null:
		return
	_options_menu.open_menu()


func _set_inventory_ui_visible(on: bool) -> void:
	var inv := get_node_or_null("/root/ATKInventory")
	if inv != null:
		var ui := inv.get_node_or_null("DefaultInventoryUI")
		if ui != null and ui.has_method("set_hud_layer_visible"):
			ui.set_hud_layer_visible(on)
		elif ui != null:
			ui.visible = on

	var journal := get_node_or_null("/root/ATKJournal")
	if journal != null:
		var ju := journal.get_node_or_null("DefaultObjectiveJournalUI")
		if ju != null and ju.has_method("set_hud_layer_visible"):
			ju.set_hud_layer_visible(on)
		elif ju != null:
			ju.visible = on

	var hints := get_node_or_null("/root/ATKHints")
	if hints != null:
		var hu := hints.get_node_or_null("DefaultHintUI")
		if hu != null and hu.has_method("set_hud_layer_visible"):
			hu.set_hud_layer_visible(on)
		elif hu != null:
			hu.visible = on


func _ensure_options_controls() -> void:
	_options_menu = ATKOptionsMenu.new()
	_options_menu.name = "OptionsMenu"
	add_child(_options_menu)
