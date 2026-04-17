@tool
class_name ATKActionStepAddItem
extends ATKActionStep

@export var item_id := ""
@export var amount := 1


func run(_context: ATKActionContext) -> void:
	if item_id.is_empty():
		ATKLog.warn("Add-item step '%s' has empty item_id." % _debug_name(), "ATKAction")
		return
	var inv := _get_inventory()
	if inv == null:
		ATKLog.warn("ATKInventory missing for add-item step '%s'." % _debug_name(), "ATKAction")
		return
	var n := maxi(amount, 1)
	inv.add_item(item_id, n)
	ATKLog.debug("Added item '%s' x%d." % [item_id, n], "ATKAction")


func _get_inventory() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKInventory")
