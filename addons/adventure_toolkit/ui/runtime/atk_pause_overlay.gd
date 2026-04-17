extends CanvasLayer

## Minimal pause / menu shell (Phase 14 / T14.4). Uses [member get_tree].paused.
## [member PROCESS_MODE_ALWAYS] so the overlay still runs while the tree is paused.
## Keyboard: [member keyboard_action] in **Input Map** (default [code]atk_pause_menu[/code], falls back to Escape).
## Call [method open_pause_menu] from a HUD button for mouse-only games. **Save / Load** opens [ATKSave]'s save panel.
## **Quit to desktop** shows a confirmation dialog before quitting the application.


const _DEFAULT_TOGGLE_KEY := KEY_ESCAPE

@export var allow_keyboard_toggle := true
@export var keyboard_action := "atk_pause_menu"
@export_file("*.tscn") var main_menu_scene_path := "res://addons/adventure_toolkit/demo/sample_game/scenes/atk_main_menu.tscn"

@onready var _root: Control = $Root
@onready var _btn_resume: Button = $Root/Panel/Margin/VBox/ResumeButton
@onready var _btn_saves: Button = $Root/Panel/Margin/VBox/SaveLoadButton
@onready var _btn_options: Button = $Root/Panel/Margin/VBox/OptionsButton
@onready var _btn_main_menu: Button = $Root/Panel/Margin/VBox/MainMenuButton
@onready var _btn_quit: Button = $Root/Panel/Margin/VBox/QuitButton
@onready var _modal_backdrop: ColorRect = $ModalBackdrop
@onready var _quit_confirm: ConfirmationDialog = $QuitConfirmDialog
@onready var _main_menu_confirm: ConfirmationDialog = $MainMenuConfirmDialog
var _options_menu: ATKOptionsMenu

## True when **Save / Load** was pressed from this overlay; we hid this layer so only the save panel shows.
var _save_opened_from_pause_menu := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_resume.pressed.connect(_on_resume_pressed)
	_btn_saves.pressed.connect(_on_save_load_pressed)
	_btn_options.pressed.connect(_on_options_pressed)
	_btn_main_menu.pressed.connect(_on_main_menu_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)
	_ensure_options_button()
	_quit_confirm.confirmed.connect(_on_quit_confirmed)
	_main_menu_confirm.confirmed.connect(_on_main_menu_confirmed)
	_main_menu_confirm.canceled.connect(_sync_quit_modal_backdrop)
	_quit_confirm.canceled.connect(_sync_quit_modal_backdrop)
	_main_menu_confirm.visibility_changed.connect(_sync_quit_modal_backdrop)
	_quit_confirm.visibility_changed.connect(_sync_quit_modal_backdrop)

	if not keyboard_action.strip_edges().is_empty():
		ATKUiInputActions.ensure_action_with_default_key(keyboard_action, _DEFAULT_TOGGLE_KEY)


func open_pause_menu() -> void:
	if get_tree().paused:
		return
	_set_paused(true)


func _unhandled_input(event: InputEvent) -> void:
	if not allow_keyboard_toggle:
		return
	if not _keyboard_shortcuts_allowed():
		return
	if keyboard_action.strip_edges().is_empty():
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not event.is_action_pressed(StringName(keyboard_action)):
		return
	var host := get_parent()
	var save_ui: Node = null
	if host != null:
		save_ui = host.get_node_or_null("DefaultSaveUI")
	if save_ui != null and save_ui.visible and not get_tree().paused:
		save_ui.visible = false
		get_viewport().set_input_as_handled()
		return
	_toggle_pause()
	get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	_set_paused(not get_tree().paused)


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	visible = on
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_quit_pressed() -> void:
	_quit_confirm.popup_centered()


func _on_main_menu_pressed() -> void:
	_main_menu_confirm.popup_centered()


func _on_options_pressed() -> void:
	if _options_menu == null:
		return
	_options_menu.open_menu()


func _sync_quit_modal_backdrop() -> void:
	_modal_backdrop.visible = _quit_confirm.visible or _main_menu_confirm.visible


func _on_quit_modal_backdrop_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _quit_confirm.visible:
		if _main_menu_confirm.visible:
			_main_menu_confirm.hide()
		else:
			return
	elif _quit_confirm.visible:
		_quit_confirm.hide()
	get_viewport().set_input_as_handled()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_main_menu_confirmed() -> void:
	_save_opened_from_pause_menu = false
	_set_paused(false)
	if main_menu_scene_path.strip_edges().is_empty():
		push_warning("ATKPauseOverlay: main_menu_scene_path is empty.")
		return
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null or not scenes.has_method("load_scene"):
		push_warning("ATKPauseOverlay: ATKScenes autoload missing.")
		return
	var err: Error = await scenes.load_scene(main_menu_scene_path, "")
	if err != OK:
		push_warning("ATKPauseOverlay: failed to load main menu (%d)." % err)


func _on_save_load_pressed() -> void:
	var host := get_parent()
	if host == null:
		return
	var save_ui := host.get_node_or_null("DefaultSaveUI")
	if save_ui != null:
		_save_opened_from_pause_menu = visible
		if _save_opened_from_pause_menu:
			visible = false
			_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		save_ui.visible = true
		if save_ui.has_method("refresh_panel"):
			save_ui.call("refresh_panel")


## Called when the save panel **Close** button hides the UI. If we hid the pause menu for Save/Load, show it again.
func notify_save_ui_closed() -> void:
	if _save_opened_from_pause_menu and get_tree().paused:
		visible = true
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_opened_from_pause_menu = false


## After a successful load, leave pause mode and gameplay (pause overlay stays hidden).
func dismiss_after_successful_load() -> void:
	_save_opened_from_pause_menu = false
	if get_tree().paused:
		_set_paused(false)


func _ensure_options_button() -> void:
	_options_menu = ATKOptionsMenu.new()
	_options_menu.name = "OptionsMenu"
	add_child(_options_menu)


func _keyboard_shortcuts_allowed() -> bool:
	var settings := get_node_or_null("/root/ATKSettings")
	if settings == null or not settings.has_method("is_keyboard_shortcuts_enabled"):
		return true
	return bool(settings.call("is_keyboard_shortcuts_enabled"))
