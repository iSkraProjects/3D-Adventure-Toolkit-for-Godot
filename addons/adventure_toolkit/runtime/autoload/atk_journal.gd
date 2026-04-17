extends Node

## Narrative journal log (Phase 16 / T16.1). Persists via [ATKSave]. Objectives are read from [ATKQuests] in the UI.


signal journal_changed


const _DEFAULT_JOURNAL_UI := preload("res://addons/adventure_toolkit/ui/runtime/atk_objective_journal_ui.tscn")


var _entries: Array[Dictionary] = []


func _ready() -> void:
	var ui: Node = _DEFAULT_JOURNAL_UI.instantiate()
	ui.name = "DefaultObjectiveJournalUI"
	add_child(ui)


func add_journal_entry(title: String, body: String, entry_id: String = "") -> String:
	var id := entry_id.strip_edges()
	if id.is_empty():
		id = "entry_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	var e := {
		"entry_id": id,
		"title": title.strip_edges(),
		"body": body,
		"created_unix": Time.get_unix_time_from_system(),
	}
	_entries.append(e)
	_normalize_entries()
	emit_signal("journal_changed")
	ATKLog.debug("Journal entry added '%s'." % id, "ATKJournal")
	return id


func remove_journal_entry(entry_id: String) -> void:
	if entry_id.is_empty():
		return
	for i in range(_entries.size()):
		if str(_entries[i].get("entry_id", "")) == entry_id:
			_entries.remove_at(i)
			emit_signal("journal_changed")
			ATKLog.debug("Journal entry removed '%s'." % entry_id, "ATKJournal")
			return


func clear_journal_entries() -> void:
	if _entries.is_empty():
		return
	_entries.clear()
	emit_signal("journal_changed")
	ATKLog.info("Journal cleared.", "ATKJournal")


func get_journal_entries() -> Array:
	var out: Array = []
	for e in _entries:
		out.append((e as Dictionary).duplicate(true))
	return out


func export_journal_state() -> Dictionary:
	var raw: Array = []
	for e in _entries:
		raw.append(e)
	return {"v": 1, "entries": ATKSerialize.duplicate_array(raw)}


func import_journal_state(payload: Variant) -> void:
	if not (payload is Dictionary):
		return
	var d: Dictionary = payload
	var ver := int(d.get("v", 0))
	if ver < 1:
		return
	var raw: Variant = d.get("entries", [])
	if raw is Array:
		_entries.clear()
		for item in raw as Array:
			if item is Dictionary:
				_entries.append(ATKSerialize.duplicate_dictionary(item as Dictionary))
		_normalize_entries()
		emit_signal("journal_changed")
		ATKLog.info("Journal state imported (%d entries)." % _entries.size(), "ATKJournal")


func _normalize_entries() -> void:
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		if not e.has("entry_id"):
			e["entry_id"] = "entry_%d" % i
		if not e.has("title"):
			e["title"] = ""
		if not e.has("body"):
			e["body"] = ""
		if not e.has("created_unix"):
			e["created_unix"] = 0.0
