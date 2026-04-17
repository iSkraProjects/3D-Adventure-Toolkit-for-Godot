extends Node

## Phase 18.1: cutscene hooks for action-driven integration.
## This autoload does not implement timeline playback itself; instead it standardizes
## request/start/finish/skip signals so content can bind any cutscene backend.

signal cutscene_requested(cutscene_id: String, context: Dictionary)
signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String)
signal cutscene_skipped(cutscene_id: String)
signal cutscene_resolved(cutscene_id: String, result: String)

var _active_cutscene_id := ""
var _last_resolution_by_id: Dictionary = {}

const RESOLUTION_FINISHED := "finished"
const RESOLUTION_SKIPPED := "skipped"


func has_active_cutscene() -> bool:
	return not _active_cutscene_id.is_empty()


func get_active_cutscene_id() -> String:
	return _active_cutscene_id


func request_cutscene(cutscene_id: String, context: Dictionary = {}, await_completion := false) -> bool:
	var id := cutscene_id.strip_edges()
	if id.is_empty():
		ATKLog.warn("request_cutscene called with empty cutscene_id.", "ATKCutscenes")
		return false
	if has_active_cutscene():
		ATKLog.warn("Cannot request '%s': cutscene '%s' is already active." % [id, _active_cutscene_id], "ATKCutscenes")
		return false

	_active_cutscene_id = id
	ATKLog.info("Cutscene requested: '%s'." % id, "ATKCutscenes")
	cutscene_requested.emit(id, context.duplicate(true))

	if await_completion:
		while _active_cutscene_id == id:
			await get_tree().process_frame
	return true


func mark_cutscene_started(cutscene_id: String) -> void:
	var id := cutscene_id.strip_edges()
	if id.is_empty():
		return
	if _active_cutscene_id.is_empty():
		_active_cutscene_id = id
	elif _active_cutscene_id != id:
		ATKLog.warn("mark_cutscene_started mismatch: active='%s' incoming='%s'." % [_active_cutscene_id, id], "ATKCutscenes")
	_active_cutscene_id = id
	ATKLog.info("Cutscene started: '%s'." % id, "ATKCutscenes")
	cutscene_started.emit(id)


func mark_cutscene_finished(cutscene_id: String) -> void:
	var id := cutscene_id.strip_edges()
	if id.is_empty():
		return
	if _active_cutscene_id != id:
		ATKLog.warn("mark_cutscene_finished mismatch: active='%s' incoming='%s'." % [_active_cutscene_id, id], "ATKCutscenes")
	_active_cutscene_id = ""
	_last_resolution_by_id[id] = RESOLUTION_FINISHED
	ATKLog.info("Cutscene finished: '%s'." % id, "ATKCutscenes")
	cutscene_finished.emit(id)
	cutscene_resolved.emit(id, RESOLUTION_FINISHED)


func skip_active_cutscene() -> void:
	if _active_cutscene_id.is_empty():
		return
	var id := _active_cutscene_id
	_active_cutscene_id = ""
	_last_resolution_by_id[id] = RESOLUTION_SKIPPED
	ATKLog.info("Cutscene skipped: '%s'." % id, "ATKCutscenes")
	cutscene_skipped.emit(id)
	cutscene_resolved.emit(id, RESOLUTION_SKIPPED)


func get_last_resolution(cutscene_id: String) -> String:
	return str(_last_resolution_by_id.get(cutscene_id.strip_edges(), ""))
