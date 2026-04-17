class_name ATKPickup
extends ATKAdventureObject

## World pickups use [member item_id] with [ATKInventoryItemDefinition] data on [ATKInventory]. If that definition has
## [member ATKInventoryItemDefinition.unique] enabled, this node hides when the item was granted elsewhere or already consumed.


@export var item_id := ""
@export var consume_on_pickup := true
@export var show_pickup_feedback := true
@export_multiline var pickup_feedback_template := "You collected {name} in your inventory."


func _ready() -> void:
	super._ready()
	_apply_collected_state()
	_apply_unique_world_availability()


func _validate_property(property: Dictionary) -> void:
	if property.get("name", "") != "item_id":
		return
	var ids := _collect_inventory_item_ids()
	if ids.is_empty():
		return
	property["hint"] = PROPERTY_HINT_ENUM
	property["hint_string"] = ",".join(ids)


func interact_default(actor: Node) -> void:
	if not can_interact():
		return
	if _resolve_active_verb(actor) == "inspect":
		await super.interact_default(actor)
		return
	if item_id.is_empty():
		ATKLog.warn("Pickup '%s' has no item_id." % object_id, "ATKPickup")
		return

	var inventory := _get_inventory_manager()
	if inventory == null:
		ATKLog.warn("ATKInventory is unavailable for pickup '%s'." % object_id, "ATKPickup")
		return

	if inventory.has_method("is_unique_item_locked_out") and inventory.is_unique_item_locked_out(item_id):
		ATKLog.info("Pickup '%s': unique item '%s' already held or spent." % [object_id, item_id], "ATKPickup")
		return

	inventory.add_item(item_id, 1)
	ATKLog.info("Picked up '%s'." % item_id, "ATKPickup")

	if show_pickup_feedback:
		var label := display_name.strip_edges() if not display_name.strip_edges().is_empty() else item_id
		var line := pickup_feedback_template.replace("{name}", label)
		_push_interaction_message(line)

	if consume_on_pickup:
		set_runtime_enabled(false)
		set_runtime_interactable(false)
		set_runtime_visible(false)
		_persist_runtime_state_value("collected", true)


func _apply_collected_state() -> void:
	if object_id.is_empty():
		return

	var state := _get_state_manager()
	if state == null:
		return

	var collected := bool(state.get_object(object_id, "collected", false))
	if not collected:
		return

	set_runtime_enabled(false)
	set_runtime_interactable(false)
	set_runtime_visible(false)


## Hides this pickup if a [i]unique[/i] item was granted elsewhere or already consumed (same rules as [ATKInventory]).
func _apply_unique_world_availability() -> void:
	if item_id.is_empty():
		return
	var inventory := _get_inventory_manager()
	if inventory == null or not inventory.has_method("is_unique_item_locked_out"):
		return
	if not bool(inventory.call("is_unique_item_locked_out", item_id)):
		return
	set_runtime_enabled(false)
	set_runtime_interactable(false)
	set_runtime_visible(false)


func _get_inventory_manager() -> Node:
	return get_node_or_null("/root/ATKInventory")


func _collect_inventory_item_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	var dir := DirAccess.open("res://addons/adventure_toolkit/resources/inventory/items")
	if dir == null:
		return ids
	_collect_inventory_item_ids_in_dir("res://addons/adventure_toolkit/resources/inventory/items", ids)
	ids.sort()
	return ids


func _collect_inventory_item_ids_in_dir(path: String, out_ids: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect_inventory_item_ids_in_dir("%s/%s" % [path, sub], out_ids)
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var full_path := "%s/%s" % [path, file_name]
		var res := load(full_path)
		if not (res is ATKInventoryItemDefinition):
			continue
		var item := (res as ATKInventoryItemDefinition).item_id.strip_edges()
		if item.is_empty():
			continue
		if not out_ids.has(item):
			out_ids.append(item)
