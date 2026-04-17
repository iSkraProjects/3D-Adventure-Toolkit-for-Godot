@tool
class_name ATKActionStepAddItem
extends ATKActionStep

@export var item_id := ""
@export var amount := 1
## Optional icon for this add-item action (useful when item is granted by dialogue/cutscene and has no world pickup node).
@export var icon_override: Texture2D


func run(_context: ATKActionContext) -> void:
	if item_id.is_empty():
		ATKLog.warn("Add-item step '%s' has empty item_id." % _debug_name(), "ATKAction")
		return
	var inv := _get_inventory()
	if inv == null:
		ATKLog.warn("ATKInventory missing for add-item step '%s'." % _debug_name(), "ATKAction")
		return
	var n := maxi(amount, 1)
	if icon_override != null and inv.has_method("register_runtime_item_icon"):
		inv.call("register_runtime_item_icon", item_id, icon_override)
	inv.add_item(item_id, n)
	ATKLog.debug("Added item '%s' x%d." % [item_id, n], "ATKAction")


func _get_inventory() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKInventory")
