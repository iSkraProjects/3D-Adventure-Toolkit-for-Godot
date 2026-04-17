@tool
class_name ATKConditionHasItem
extends ATKCondition


@export var item_id := ""
@export var amount := 1


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if item_id.is_empty():
		return fail("Has-item condition '%s' is missing item_id." % get_debug_name())

	var inventory := _resolve_inventory(context)
	if inventory == null:
		return fail(
			"Has-item condition '%s' could not find ATKInventory." % get_debug_name(),
			{"item_id": item_id, "amount": amount}
		)

	var required_amount := maxi(amount, 1)
	var owns_item: bool = inventory.has_item(item_id, required_amount)
	if owns_item:
		return succeed(
			"Inventory contains '%s' x%d." % [item_id, required_amount],
			{"item_id": item_id, "amount": required_amount}
		)

	return fail(
		"Inventory is missing '%s' x%d." % [item_id, required_amount],
		{"item_id": item_id, "amount": required_amount}
	)


func _resolve_inventory(context: Dictionary) -> Node:
	if context.has("inventory") and context["inventory"] is Node:
		return context["inventory"] as Node

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKInventory")
