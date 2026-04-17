@tool
class_name ATKConditionUniqueItemObtainable
extends ATKCondition

## Passes when [member item_id] can still be added: not already held and not marked spent for unique items
## (see [ATKInventory]). Non-unique items always pass. Use on a dialogue node with [member ATKDialogueNode.fallback_next_node_id]
## to branch when the player already has the item or has used it up.


@export var item_id := ""


func _evaluate_internal(context: Dictionary) -> Dictionary:
	if item_id.is_empty():
		return fail("Unique-item-obtainable condition '%s' has empty item_id." % get_debug_name())

	var inventory := _resolve_inventory(context)
	if inventory == null:
		return fail(
			"Unique-item-obtainable condition '%s' could not find ATKInventory." % get_debug_name(),
			{"item_id": item_id}
		)

	if not inventory.has_method("can_still_obtain_unique_item"):
		return fail(
			"ATKInventory does not implement unique-item checks (outdated addon?).",
			{"item_id": item_id}
		)

	if bool(inventory.call("can_still_obtain_unique_item", item_id)):
		return succeed("Item '%s' can still be obtained." % item_id, {"item_id": item_id})

	return fail("Unique item '%s' is already held or has been spent." % item_id, {"item_id": item_id})


func _resolve_inventory(context: Dictionary) -> Node:
	if context.has("inventory") and context["inventory"] is Node:
		return context["inventory"] as Node

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ATKInventory")
