@tool
class_name ATKPuzzleController
extends Node3D

## Runtime puzzle instance. Persists `lifecycle` under `ATKState` object scope using `puzzle_id`.


const LIFECYCLE_KEY := "lifecycle"
const STATE_UNSOLVED := "unsolved"
const STATE_SOLVED := "solved"
const STATE_FAILED := "failed"


signal puzzle_lifecycle_changed(puzzle_id: String, new_state: String, previous_state: String)
signal puzzle_solved(puzzle_id: String)
signal puzzle_failed(puzzle_id: String)
signal puzzle_reset(puzzle_id: String)


@export var puzzle_id := ""
@export var definition: ATKPuzzleDefinition


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if puzzle_id.is_empty():
		return
	var state := _get_state()
	if state == null:
		return
	if not state.has_object(puzzle_id, LIFECYCLE_KEY):
		state.set_object(puzzle_id, LIFECYCLE_KEY, STATE_UNSOLVED)

	puzzle_solved.connect(_on_hints_lifecycle_inactive)
	puzzle_failed.connect(_on_hints_lifecycle_inactive)
	puzzle_reset.connect(_on_hints_puzzle_reset)
	call_deferred("_sync_puzzle_hint_bank_to_autoload")


func _get_configuration_warnings() -> PackedStringArray:
	var issues := PackedStringArray()
	if puzzle_id.is_empty():
		issues.append("ATKPuzzleController requires a stable puzzle_id (object state key).")
	return issues


func get_lifecycle_state() -> String:
	if puzzle_id.is_empty():
		return STATE_UNSOLVED
	var state := _get_state()
	if state == null:
		return STATE_UNSOLVED
	return str(state.get_object(puzzle_id, LIFECYCLE_KEY, STATE_UNSOLVED))


func is_solved() -> bool:
	return get_lifecycle_state() == STATE_SOLVED


func is_failed() -> bool:
	return get_lifecycle_state() == STATE_FAILED


func mark_solved(actor: Node = null) -> void:
	await _set_lifecycle(STATE_SOLVED, actor, true)


func mark_failed(actor: Node = null) -> void:
	await _set_lifecycle(STATE_FAILED, actor, true)


func reset_puzzle(actor: Node = null) -> void:
	await _set_lifecycle(STATE_UNSOLVED, actor, true)


func _set_lifecycle(new_state: String, actor: Node, run_definition_hooks: bool) -> void:
	if puzzle_id.is_empty():
		return
	var state := _get_state()
	if state == null:
		return
	var previous := str(state.get_object(puzzle_id, LIFECYCLE_KEY, STATE_UNSOLVED))
	if previous == new_state:
		return
	state.set_object(puzzle_id, LIFECYCLE_KEY, new_state)
	emit_signal("puzzle_lifecycle_changed", puzzle_id, new_state, previous)
	match new_state:
		STATE_SOLVED:
			emit_signal("puzzle_solved", puzzle_id)
		STATE_FAILED:
			emit_signal("puzzle_failed", puzzle_id)
		STATE_UNSOLVED:
			emit_signal("puzzle_reset", puzzle_id)
	if not run_definition_hooks or definition == null:
		return
	var seq: ATKActionSequence = null
	match new_state:
		STATE_SOLVED:
			seq = definition.on_success_actions
		STATE_FAILED:
			seq = definition.on_failure_actions
		STATE_UNSOLVED:
			seq = definition.on_reset_actions
	if seq != null and not seq.steps.is_empty():
		var ctx := _build_context(actor)
		await ATKActionRunner.run_sequence(seq, ctx, Callable())


func _build_context(actor: Node) -> ATKActionContext:
	var c := ATKActionContext.new()
	c.actor = actor
	c.target = self
	c.object_id = puzzle_id
	c.scene_id = _scene_id()
	c.verb = "puzzle"
	var inv := get_node_or_null("/root/ATKInventory")
	if inv != null and inv.has_method("get_selected_item"):
		c.selected_item_id = str(inv.call("get_selected_item"))
	return c


func _scene_id() -> String:
	var scenes := get_node_or_null("/root/ATKScenes")
	if scenes == null:
		return ""
	return str(scenes.current_scene_id)


func _get_state() -> Node:
	return get_node_or_null("/root/ATKState")


func _sync_puzzle_hint_bank_to_autoload() -> void:
	var hints := get_node_or_null("/root/ATKHints")
	if hints == null:
		return
	if definition != null and definition.puzzle_hint_bank != null and hints.has_method("register_hint_bank"):
		hints.register_hint_bank(definition.puzzle_hint_bank)
	if definition == null or definition.puzzle_hint_bank == null:
		if hints.has_method("set_puzzle_hint_bank"):
			hints.set_puzzle_hint_bank("")
		return
	var bid := definition.puzzle_hint_bank.hint_bank_id.strip_edges()
	if bid.is_empty():
		if hints.has_method("set_puzzle_hint_bank"):
			hints.set_puzzle_hint_bank("")
		return
	if get_lifecycle_state() != STATE_UNSOLVED:
		if hints.has_method("set_puzzle_hint_bank"):
			hints.set_puzzle_hint_bank("")
		return
	if hints.has_method("set_puzzle_hint_bank"):
		hints.set_puzzle_hint_bank(bid)


func _on_hints_lifecycle_inactive(_puzzle_id: String) -> void:
	var hints := get_node_or_null("/root/ATKHints")
	if hints != null and hints.has_method("set_puzzle_hint_bank"):
		hints.set_puzzle_hint_bank("")


func _on_hints_puzzle_reset(_puzzle_id: String) -> void:
	var hints := get_node_or_null("/root/ATKHints")
	if hints != null and definition != null and definition.puzzle_hint_bank != null:
		var bid := definition.puzzle_hint_bank.hint_bank_id.strip_edges()
		if not bid.is_empty() and hints.has_method("reset_bank_progress"):
			hints.reset_bank_progress(bid)
	_sync_puzzle_hint_bank_to_autoload()
