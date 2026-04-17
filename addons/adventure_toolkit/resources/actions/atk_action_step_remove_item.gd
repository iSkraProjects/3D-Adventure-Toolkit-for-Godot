@tool
class_name ATKActionStepRemoveItem
extends ATKActionStep

@export var item_id := ""
@export var amount := 1


func run(_context: ATKActionContext) -> void:
	if item_id.is_empty():
		ATKLog.warn("Remove-item step '%s' has empty item_id." % _debug_name(), "ATKAction")
		return
	var inv := _get_inventory()
	if inv == null:
		ATKLog.warn("ATKInventory missing for remove-item step '%s'." % _debug_name(), "ATKAction")
		return
	var n := maxi(amount, 1)
	var ok: bool = inv.remove_item(item_id, n)
	if not ok:
		ATKLog.warn("Remove-item step '%s' could not remove '%s' x%d." % [_debug_name(), item_id, n], "ATKAction")
	else:
		ATKLog.debug("Removed item '%s' x%d." % [item_id, n], "ATKAction")


func _get_inventory() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKInventory")
