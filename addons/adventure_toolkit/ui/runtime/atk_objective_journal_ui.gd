extends CanvasLayer

## Objectives (from [ATKQuests] definitions + runtime stage) and journal notes ([ATKJournal]). Parented under [ATKJournal] by default.


const _DEFAULT_TOGGLE_KEY := KEY_J

@export var allow_keyboard_toggle := true
@export var keyboard_action := "atk_toggle_journal"
@export var start_visible := false

@onready var _root: Control = $Root
@onready var _open_btn: TextureButton = $Root/OpenButton
@onready var _panel: PanelContainer = $Root/Panel
@onready var _objectives: RichTextLabel = $Root/Panel/Margin/VBox/Objectives
@onready var _journal_list: ItemList = $Root/Panel/Margin/VBox/JournalList
@onready var _journal_body: RichTextLabel = $Root/Panel/Margin/VBox/JournalBody
@onready var _btn_close: Button = $Root/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_open_button_icon()
	_panel.visible = start_visible
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if start_visible else Control.MOUSE_FILTER_IGNORE
	_open_btn.pressed.connect(_on_open_pressed)
	_btn_close.pressed.connect(_on_close_pressed)
	_journal_list.item_selected.connect(_on_journal_item_selected)
	_journal_list.item_clicked.connect(_on_journal_item_clicked)

	var quests := get_node_or_null("/root/ATKQuests")
	if quests != null:
		if quests.has_signal("quest_stage_changed"):
			quests.quest_stage_changed.connect(_on_quests_changed)
		if quests.has_signal("quest_started"):
			quests.quest_started.connect(_on_quests_changed_unary)
		if quests.has_signal("quest_completed"):
			quests.quest_completed.connect(_on_quests_changed_unary)

	var journal := get_node_or_null("/root/ATKJournal")
	if journal != null and journal.has_signal("journal_changed"):
		journal.journal_changed.connect(_on_journal_changed)

	_refresh_all()

	if not keyboard_action.strip_edges().is_empty():
		ATKUiInputActions.ensure_action_with_default_key(keyboard_action, _DEFAULT_TOGGLE_KEY)


func is_journal_panel_open() -> bool:
	return _panel.visible


## Hides the HUD (open button + panel) when false (e.g. main menu).
func set_hud_layer_visible(on: bool) -> void:
	visible = on
	if not on:
		_set_panel_open(false)


func _on_open_pressed() -> void:
	_set_panel_open(not _panel.visible)


func _on_close_pressed() -> void:
	_set_panel_open(false)


func _on_quests_changed(_q: String, _s: int, _p: int) -> void:
	_refresh_objectives()


func _on_quests_changed_unary(_q: String) -> void:
	_refresh_objectives()


func _on_journal_changed() -> void:
	_refresh_journal_list()


func _set_panel_open(open: bool) -> void:
	_panel.visible = open
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open:
		_refresh_all()
		_journal_list.call_deferred("grab_focus")


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
	_set_panel_open(not _panel.visible)
	get_viewport().set_input_as_handled()


func _refresh_all() -> void:
	_refresh_objectives()
	_refresh_journal_list()


func _refresh_objectives() -> void:
	var quests := get_node_or_null("/root/ATKQuests")
	if quests == null:
		_objectives.text = "[i]ATKQuests unavailable.[/i]"
		return

	var ids: PackedStringArray = quests.get_all_quest_ids()
	if ids.is_empty():
		_objectives.text = "[i]No quest progress yet.[/i]"
		return

	var lines: Array[String] = []
	for qid in ids:
		var def: ATKQuestDefinition = quests.get_quest_definition(qid)
		if def != null and def.is_hidden:
			if not quests.is_quest_started(qid) and not quests.is_quest_completed(qid):
				continue
		if not quests.is_quest_started(qid) and not quests.is_quest_completed(qid):
			continue

		var title := qid
		if def != null and not def.display_name.strip_edges().is_empty():
			title = def.display_name.strip_edges()

		var stage: int = quests.get_quest_stage(qid)
		var detail := ""
		if quests.is_quest_completed(qid):
			detail = "Completed."
		elif def != null and stage >= 0 and stage < def.objective_stage_labels.size():
			detail = str(def.objective_stage_labels[stage]).strip_edges()
		elif def != null and not def.description.strip_edges().is_empty():
			var desc_lines: PackedStringArray = def.description.strip_edges().split("\n")
			detail = str(desc_lines[0]).strip_edges() if desc_lines.size() > 0 else ""
		else:
			detail = "Stage %d" % stage

		lines.append("• [b]%s[/b]: %s" % [title, detail])

	if lines.is_empty():
		_objectives.text = "[i]No active objectives.[/i]"
	else:
		_objectives.text = "\n".join(lines)


func _refresh_journal_list() -> void:
	var journal := get_node_or_null("/root/ATKJournal")
	_journal_list.clear()
	_journal_body.text = ""
	if journal == null or not journal.has_method("get_journal_entries"):
		_journal_body.text = "[i]ATKJournal unavailable.[/i]"
		return

	var entries: Array = journal.call("get_journal_entries")
	if entries.is_empty():
		_journal_body.text = "[i]No journal entries yet.[/i]"
		return

	for i in range(entries.size()):
		var e: Variant = entries[i]
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e
		var t := str(ed.get("title", "Untitled")).strip_edges()
		if t.is_empty():
			t = str(ed.get("entry_id", "?"))
		var idx := _journal_list.add_item(t)
		_journal_list.set_item_metadata(idx, i)

	if _journal_list.item_count > 0:
		_journal_list.select(0)
		_apply_journal_index(0)


func _on_journal_item_selected(index: int) -> void:
	_apply_journal_index(index)


func _on_journal_item_clicked(index: int, _at: Vector2, _btn: int) -> void:
	_apply_journal_index(index)


func _apply_journal_index(list_row_index: int) -> void:
	var journal := get_node_or_null("/root/ATKJournal")
	if journal == null or not journal.has_method("get_journal_entries"):
		return
	var entries: Array = journal.call("get_journal_entries")
	if list_row_index < 0 or list_row_index >= _journal_list.item_count:
		return
	var entry_i := int(_journal_list.get_item_metadata(list_row_index))
	if entry_i < 0 or entry_i >= entries.size():
		return
	var e: Variant = entries[entry_i]
	if not (e is Dictionary):
		return
	var ed: Dictionary = e
	var title := str(ed.get("title", "")).strip_edges()
	var body := str(ed.get("body", ""))
	if title.is_empty():
		title = str(ed.get("entry_id", "Entry"))
	if body.strip_edges().is_empty():
		body = "[i](No text.)[/i]"
	_journal_body.text = "[b]%s[/b]\n%s" % [title, body]


func _apply_open_button_icon() -> void:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.42, 0.36, 0.28))
	for y in range(14, 36):
		for x in range(12, 37):
			img.set_pixel(x, y, Color(0.92, 0.88, 0.78))
	_open_btn.texture_normal = ImageTexture.create_from_image(img)


func _keyboard_shortcuts_allowed() -> bool:
	var settings := get_node_or_null("/root/ATKSettings")
	if settings == null or not settings.has_method("is_keyboard_shortcuts_enabled"):
		return true
	return bool(settings.call("is_keyboard_shortcuts_enabled"))
