extends Node

## Central quest progression (Phase 11). Persists via `ATKSave` using `export_quest_save` / `import_quest_save`.


signal quest_stage_changed(quest_id: String, stage: int, previous_stage: int)
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)


var _definitions: Dictionary = {} # quest_id -> ATKQuestDefinition
var _quests: Dictionary = {} # quest_id -> { stage: int, started: bool, completed: bool }


func register_quest_definition(definition: ATKQuestDefinition) -> void:
	if definition == null or definition.quest_id.is_empty():
		return
	_definitions[definition.quest_id] = definition
	ATKLog.debug("Registered quest definition '%s'." % definition.quest_id, "ATKQuests")


func unregister_quest_definition(quest_id: String) -> void:
	_definitions.erase(quest_id)


func get_quest_definition(quest_id: String) -> ATKQuestDefinition:
	if not _definitions.has(quest_id):
		return null
	return _definitions[quest_id] as ATKQuestDefinition


func get_all_quest_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for qid in _quests.keys():
		out.append(str(qid))
	out.sort()
	return out


func start_quest(quest_id: String) -> void:
	if quest_id.is_empty():
		return
	var e := _ensure_entry(quest_id)
	if bool(e.get("started", false)) and not bool(e.get("completed", false)):
		return
	e["started"] = true
	e["completed"] = false
	e["stage"] = 0
	emit_signal("quest_started", quest_id)
	ATKLog.info("Quest started: '%s'." % quest_id, "ATKQuests")


func complete_quest(quest_id: String) -> void:
	if quest_id.is_empty():
		return
	var e := _ensure_entry(quest_id)
	if bool(e.get("completed", false)):
		return
	e["started"] = true
	e["completed"] = true
	emit_signal("quest_completed", quest_id)
	ATKLog.info("Quest completed: '%s'." % quest_id, "ATKQuests")


func get_quest_stage(quest_id: String) -> int:
	if quest_id.is_empty() or not _quests.has(quest_id):
		return 0
	return int(_quests[quest_id].get("stage", 0))


func set_quest_stage(quest_id: String, stage: int) -> void:
	if quest_id.is_empty():
		return
	var e := _ensure_entry(quest_id)
	e["started"] = true
	var previous := int(e.get("stage", 0))
	if previous == stage:
		return
	e["stage"] = stage
	emit_signal("quest_stage_changed", quest_id, stage, previous)
	ATKLog.debug("Quest '%s' stage -> %d (was %d)." % [quest_id, stage, previous], "ATKQuests")


func has_quest(quest_id: String) -> bool:
	return not quest_id.is_empty() and _quests.has(quest_id)


func is_quest_started(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false
	return bool(_quests[quest_id].get("started", false))


func is_quest_active(quest_id: String) -> bool:
	return is_quest_started(quest_id) and not is_quest_completed(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false
	return bool(_quests[quest_id].get("completed", false))


func export_quest_save() -> Dictionary:
	return {"v": 2, "entries": ATKSerialize.duplicate_dictionary(_quests)}


func export_quest_state() -> Dictionary:
	## Legacy flat map quest_id -> stage (int). Prefer `export_quest_save` for full state.
	var flat := {}
	for qid in _quests.keys():
		flat[qid] = int(_quests[qid].get("stage", 0))
	return flat


func import_quest_save(payload: Variant) -> void:
	if not (payload is Dictionary):
		return
	var d: Dictionary = payload
	var version := int(d.get("v", 0))
	if version >= 2:
		var entries: Variant = d.get("entries", {})
		if entries is Dictionary:
			_quests = ATKSerialize.duplicate_dictionary(entries as Dictionary)
			_normalize_entries()
		else:
			_quests = {}
		ATKLog.info("Quest save imported v2 (%d entries)." % _quests.size(), "ATKQuests")
		return
	_legacy_import_any(d)


func import_quest_state(payload: Dictionary) -> void:
	## Back-compat: flat `quest_id -> stage` dict from older integrations.
	_quests.clear()
	for qid in payload.keys():
		_quests[str(qid)] = {
			"stage": int(payload[qid]),
			"started": true,
			"completed": false,
		}
	_normalize_entries()
	ATKLog.info("Quest state imported (legacy flat, %d entries)." % _quests.size(), "ATKQuests")


func _legacy_import_any(d: Dictionary) -> void:
	_quests.clear()
	if d.has("entries") and d["entries"] is Dictionary:
		_migrate_legacy_entries(d["entries"] as Dictionary)
	else:
		_migrate_legacy_entries(d)
	_normalize_entries()
	ATKLog.info("Quest save imported legacy (%d entries)." % _quests.size(), "ATKQuests")


func _migrate_legacy_entries(inner: Dictionary) -> void:
	for qid in inner.keys():
		var v: Variant = inner[qid]
		if v is int or v is float:
			_quests[str(qid)] = {"stage": int(v), "started": true, "completed": false}
		elif v is Dictionary:
			var e: Dictionary = v
			_quests[str(qid)] = {
				"stage": int(e.get("stage", 0)),
				"started": bool(e.get("started", false)),
				"completed": bool(e.get("completed", false)),
			}


func _normalize_entries() -> void:
	for qid in _quests.keys():
		var e: Variant = _quests[qid]
		if not (e is Dictionary):
			_quests.erase(qid)
			continue
		var ed: Dictionary = e
		if not ed.has("stage"):
			ed["stage"] = 0
		if not ed.has("started"):
			ed["started"] = false
		if not ed.has("completed"):
			ed["completed"] = false


func _ensure_entry(quest_id: String) -> Dictionary:
	if not _quests.has(quest_id):
		_quests[quest_id] = {"stage": 0, "started": false, "completed": false}
	return _quests[quest_id]
