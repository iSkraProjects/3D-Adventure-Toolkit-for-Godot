extends Node

## Layered hints with optional cooldowns; scene bank vs puzzle-bank priority (Phase 16 / T16.2).


signal hint_delivered(bank_id: String, layer_index: int, text: String, is_last_layer: bool)
signal hint_request_failed(reason_code: String, detail: String)


const _DEFAULT_HINT_UI := preload("res://addons/adventure_toolkit/ui/runtime/atk_hint_ui.tscn")


var _banks: Dictionary = {} # hint_bank_id -> ATKHintBank
var _scene_bank_id := ""
var _puzzle_bank_id := ""
## Next layer index to reveal per bank (monotonic until [method reset_bank_progress]).
var _progress: Dictionary = {}
var _last_request_unix: Dictionary = {}


func _ready() -> void:
	var ui: Node = _DEFAULT_HINT_UI.instantiate()
	ui.name = "DefaultHintUI"
	add_child(ui)

	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes != null and scenes.has_signal("scene_transition_started"):
		scenes.scene_transition_started.connect(_on_scene_transition_started)


func _on_scene_transition_started(_scene_id: String, _scene_path: String, _spawn_id: String) -> void:
	set_puzzle_hint_bank("")


func register_hint_bank(bank: ATKHintBank) -> void:
	if bank == null or bank.hint_bank_id.strip_edges().is_empty():
		return
	_banks[bank.hint_bank_id.strip_edges()] = bank
	ATKLog.debug("Registered hint bank '%s'." % bank.hint_bank_id, "ATKHints")


func unregister_hint_bank(hint_bank_id: String) -> void:
	var id := hint_bank_id.strip_edges()
	if id.is_empty():
		return
	_banks.erase(id)


func get_hint_bank(hint_bank_id: String) -> ATKHintBank:
	var id := hint_bank_id.strip_edges()
	if id.is_empty() or not _banks.has(id):
		return null
	return _banks[id] as ATKHintBank


func set_scene_hint_bank(bank_id: String) -> void:
	_scene_bank_id = bank_id.strip_edges()


func set_puzzle_hint_bank(bank_id: String) -> void:
	_puzzle_bank_id = bank_id.strip_edges()


func get_scene_hint_bank_id() -> String:
	return _scene_bank_id


func get_puzzle_hint_bank_id() -> String:
	return _puzzle_bank_id


func get_effective_hint_bank_id() -> String:
	if not _puzzle_bank_id.is_empty() and _banks.has(_puzzle_bank_id):
		return _puzzle_bank_id
	if not _scene_bank_id.is_empty() and _banks.has(_scene_bank_id):
		return _scene_bank_id
	return ""


## Requests the next layer from the effective bank (puzzle overrides scene). Emits [signal hint_delivered] or [signal hint_request_failed].
func request_next_hint() -> void:
	var bid := get_effective_hint_bank_id()
	if bid.is_empty():
		emit_signal("hint_request_failed", "no_bank", "")
		return
	if not _banks.has(bid):
		emit_signal("hint_request_failed", "missing_bank", bid)
		return
	var bank: ATKHintBank = _banks[bid]
	var layer_lines := bank.layers
	if layer_lines.is_empty():
		emit_signal("hint_request_failed", "empty_bank", bid)
		return
	var idx: int = int(_progress.get(bid, 0))
	while idx < layer_lines.size() and str(layer_lines[idx]).strip_edges().is_empty():
		idx += 1
	if idx >= layer_lines.size():
		emit_signal("hint_request_failed", "exhausted", bid)
		return
	var cooldown := maxf(0.0, bank.cooldown_seconds)
	if cooldown > 0.0:
		var last: float = float(_last_request_unix.get(bid, -1.0e9))
		var now := Time.get_unix_time_from_system()
		var elapsed := now - last
		if elapsed < cooldown:
			emit_signal("hint_request_failed", "cooldown", str(snappedf(cooldown - elapsed, 0.1)))
			return
	var text := str(layer_lines[idx]).strip_edges()
	_progress[bid] = idx + 1
	_last_request_unix[bid] = Time.get_unix_time_from_system()
	var is_last := int(_progress[bid]) >= layer_lines.size()
	emit_signal("hint_delivered", bid, idx, text, is_last)


func reset_bank_progress(hint_bank_id: String) -> void:
	var id := hint_bank_id.strip_edges()
	if id.is_empty():
		return
	_progress.erase(id)
	_last_request_unix.erase(id)
	ATKLog.debug("Hint progress reset for '%s'." % id, "ATKHints")


func export_hints_state() -> Dictionary:
	return {"v": 1, "progress": ATKSerialize.duplicate_dictionary(_progress)}


func import_hints_state(payload: Variant) -> void:
	if not (payload is Dictionary):
		return
	var d: Dictionary = payload
	if int(d.get("v", 0)) < 1:
		return
	var prog: Variant = d.get("progress", {})
	if prog is Dictionary:
		_progress = ATKSerialize.duplicate_dictionary(prog as Dictionary)
		ATKLog.info("Hints state imported (%d banks)." % _progress.size(), "ATKHints")
