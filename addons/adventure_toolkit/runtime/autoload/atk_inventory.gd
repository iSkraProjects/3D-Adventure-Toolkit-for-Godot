extends Node

## Default inventory UI is parented here so it survives [method SceneTree.change_scene_to_packed].
## Optional [ATKInventoryItemDefinition] entries (editor and/or built-in resources) define [member ATKInventoryItemDefinition.unique]
## items: at most one copy can be held, and after it is fully removed the id is marked **spent** so it will not be granted again.


const _DEFAULT_INVENTORY_UI := preload("res://addons/adventure_toolkit/ui/runtime/atk_inventory_ui.tscn")

## Extra item definitions merged at runtime (see [member item_definitions]). Keeps unique flags without duplicating project UI setup.
const _BUILTIN_ITEM_DEF_PATHS: Array[String] = [
	"res://addons/adventure_toolkit/resources/inventory/items/item_brass_key.tres",
	"res://addons/adventure_toolkit/resources/inventory/items/item_rubber_ball.tres",
	"res://addons/adventure_toolkit/resources/inventory/items/item_yellow_ball.tres",
]


signal inventory_changed(items: Dictionary)
signal selected_item_changed(item_id: String)


## Optional: assign the same [ATKInventoryItemDefinition] list as [ATKInventoryUI] for your game. Built-in paths are merged in [method _merge_item_definition_catalog].
@export var item_definitions: Array[ATKInventoryItemDefinition] = []

var _items: Dictionary = {} # item_id -> amount
var _selected_item_id := ""
## For [member ATKInventoryItemDefinition.unique] ids: set when count drops to zero after having been held.
var _unique_expended: Dictionary = {}
var _merged_item_defs: Array[ATKInventoryItemDefinition] = []


func _ready() -> void:
	_merge_item_definition_catalog()
	var ui := _DEFAULT_INVENTORY_UI.instantiate()
	ui.name = "DefaultInventoryUI"
	add_child(ui)


func get_merged_item_definitions() -> Array[ATKInventoryItemDefinition]:
	var out: Array[ATKInventoryItemDefinition] = []
	for d in _merged_item_defs:
		out.append(d)
	return out


func _merge_item_definition_catalog() -> void:
	_merged_item_defs.clear()
	var seen: Dictionary = {}
	for d in item_definitions:
		if d == null or str(d.item_id).strip_edges().is_empty():
			continue
		seen[d.item_id] = true
		_merged_item_defs.append(d)
	for path in _BUILTIN_ITEM_DEF_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var res: Resource = load(path)
		if not (res is ATKInventoryItemDefinition):
			continue
		var def: ATKInventoryItemDefinition = res
		if str(def.item_id).strip_edges().is_empty() or seen.has(def.item_id):
			continue
		seen[def.item_id] = true
		_merged_item_defs.append(def)


func _item_def_for_id(item_id: String) -> ATKInventoryItemDefinition:
	for d in _merged_item_defs:
		if d != null and d.item_id == item_id:
			return d
	return null


func _item_is_unique(item_id: String) -> bool:
	var d := _item_def_for_id(item_id)
	return d != null and d.unique


## Unique item is no longer obtainable: player holds it, or it was consumed after being held.
func is_unique_item_locked_out(item_id: String) -> bool:
	if not _item_is_unique(item_id):
		return false
	if has_item(item_id):
		return true
	return bool(_unique_expended.get(item_id, false))


func can_still_obtain_unique_item(item_id: String) -> bool:
	return not is_unique_item_locked_out(item_id)


func has_item(item_id: String, amount: int = 1) -> bool:
	return int(_items.get(item_id, 0)) >= amount


func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return

	if _item_is_unique(item_id):
		if is_unique_item_locked_out(item_id):
			ATKLog.debug("Inventory: blocked add of unique '%s' (held or spent)." % item_id, "ATKInventory")
			return
		amount = mini(amount, 1)

	var current := int(_items.get(item_id, 0))
	_items[item_id] = current + amount
	emit_signal("inventory_changed", get_all_items())
	ATKLog.debug("Inventory add '%s' x%d" % [item_id, amount], "ATKInventory")


func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	if not has_item(item_id, amount):
		return false

	var current := int(_items.get(item_id, 0))
	var new_amount := current - amount
	if new_amount <= 0:
		_items.erase(item_id)
		if _item_is_unique(item_id):
			_unique_expended[item_id] = true
		if _selected_item_id == item_id:
			clear_selected_item()
	else:
		_items[item_id] = new_amount

	emit_signal("inventory_changed", get_all_items())
	ATKLog.debug("Inventory remove '%s' x%d" % [item_id, amount], "ATKInventory")
	return true


func select_item(item_id: String) -> bool:
	if item_id.is_empty():
		clear_selected_item()
		return true
	if not has_item(item_id):
		return false

	_selected_item_id = item_id
	emit_signal("selected_item_changed", _selected_item_id)
	ATKLog.debug("Inventory selected '%s'." % _selected_item_id, "ATKInventory")
	return true


func clear_selected_item() -> void:
	_selected_item_id = ""
	emit_signal("selected_item_changed", _selected_item_id)


func get_selected_item() -> String:
	return _selected_item_id


func get_all_items() -> Dictionary:
	return _items.duplicate(true)


func clear_inventory() -> void:
	_items.clear()
	clear_selected_item()
	emit_signal("inventory_changed", get_all_items())
	ATKLog.debug("Inventory cleared.", "ATKInventory")


func export_inventory_state() -> Dictionary:
	return {
		"items": get_all_items(),
		"selected_item_id": _selected_item_id,
		"unique_expended": _unique_expended.duplicate(true),
	}


func import_inventory_state(payload: Dictionary) -> void:
	_items = payload.get("items", {}).duplicate(true)
	_selected_item_id = str(payload.get("selected_item_id", ""))
	var ue: Variant = payload.get("unique_expended", {})
	if ue is Dictionary:
		_unique_expended = (ue as Dictionary).duplicate(true)
	else:
		_unique_expended = {}
	if not _selected_item_id.is_empty() and not has_item(_selected_item_id):
		_selected_item_id = ""
	emit_signal("inventory_changed", get_all_items())
	emit_signal("selected_item_changed", _selected_item_id)
	ATKLog.info("Inventory state imported.", "ATKInventory")
