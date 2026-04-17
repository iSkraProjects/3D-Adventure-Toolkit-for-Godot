@tool
extends EditorPlugin


const AUTOLOAD_ATK_SCENES := "ATKScenes"
const AUTOLOAD_ATK_SCENES_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_scenes.gd"
const AUTOLOAD_ATK_STATE := "ATKState"
const AUTOLOAD_ATK_STATE_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_state.gd"
const AUTOLOAD_ATK_SAVE := "ATKSave"
const AUTOLOAD_ATK_SAVE_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_save.gd"
const AUTOLOAD_ATK_INVENTORY := "ATKInventory"
const AUTOLOAD_ATK_INVENTORY_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_inventory.gd"
const AUTOLOAD_ATK_QUESTS := "ATKQuests"
const AUTOLOAD_ATK_QUESTS_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_quests.gd"
const AUTOLOAD_ATK_JOURNAL := "ATKJournal"
const AUTOLOAD_ATK_JOURNAL_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_journal.gd"
const AUTOLOAD_ATK_HINTS := "ATKHints"
const AUTOLOAD_ATK_HINTS_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_hints.gd"
const AUTOLOAD_ATK_DIALOGUE := "ATKDialogue"
const AUTOLOAD_ATK_DIALOGUE_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_dialogue.gd"
const AUTOLOAD_ATK_AUDIO := "ATKAudio"
const AUTOLOAD_ATK_AUDIO_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_audio.gd"
const AUTOLOAD_ATK_CUTSCENES := "ATKCutscenes"
const AUTOLOAD_ATK_CUTSCENES_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_cutscenes.gd"
const AUTOLOAD_ATK_SETTINGS := "ATKSettings"
const AUTOLOAD_ATK_SETTINGS_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_settings.gd"
const AUTOLOAD_ATK_EPISODES := "ATKEpisodes"
const AUTOLOAD_ATK_EPISODES_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_episodes.gd"
const AUTOLOAD_ATK_INTERACTION_FEEDBACK := "ATKInteractionFeedback"
const AUTOLOAD_ATK_INTERACTION_FEEDBACK_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_interaction_feedback.gd"
const AUTOLOAD_ATK_WORLD_UI := "ATKWorldUi"
const AUTOLOAD_ATK_WORLD_UI_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_world_ui.gd"
const AUTOLOAD_ATK_INTERACTION_HOVER := "ATKInteractionHover"
const AUTOLOAD_ATK_INTERACTION_HOVER_PATH := "res://addons/adventure_toolkit/runtime/autoload/atk_interaction_hover.gd"
const MENU_ASSIGN_STABLE_IDS := "ATK/Assign Stable IDs To Selection"
const MENU_CREATE_INTERACTION_POINTS := "ATK/Create Interaction Point Child"
const MENU_ADD_INSPECT_FALLBACK_RULE := "ATK/Add Inspect Fallback Rule"
const MENU_VALIDATE_SELECTION := "ATK/Validate Selection"
const MENU_CREATE_TEMPLATE_EXIT := "ATK/Create Template/Exit"
const MENU_CREATE_TEMPLATE_NPC_TRADE := "ATK/Create Template/NPC Trade"
const MENU_CREATE_TEMPLATE_TRIGGER := "ATK/Create Template/Trigger"
const MENU_CREATE_TEMPLATE_DOOR_LOCKED := "ATK/Create Template/Door Locked"
const MENU_CREATE_TEMPLATE_DOOR_EXIT := "ATK/Create Template/Door Exit"
const MENU_CREATE_TEMPLATE_PICKUP := "ATK/Create Template/Pickup"
const MENU_CREATE_TEMPLATE_INSPECTABLE := "ATK/Create Template/Inspectable"
const MENU_CREATE_TEMPLATE_NPC_BASIC := "ATK/Create Template/NPC Basic"
const MENU_CREATE_TEMPLATE_PUZZLE_SIMPLE := "ATK/Create Template/Puzzle Simple"
const TEMPLATE_EXIT_PATH := "res://addons/adventure_toolkit/templates/objects/Template_Exit.tscn"
const TEMPLATE_NPC_TRADE_PATH := "res://addons/adventure_toolkit/templates/objects/Template_NPC_Trade.tscn"
const TEMPLATE_TRIGGER_PATH := "res://addons/adventure_toolkit/templates/objects/Template_Trigger.tscn"
const TEMPLATE_DOOR_LOCKED_PATH := "res://addons/adventure_toolkit/templates/objects/Template_Door_Locked.tscn"
const TEMPLATE_DOOR_EXIT_PATH := "res://addons/adventure_toolkit/templates/objects/Template_Door_Exit.tscn"
const TEMPLATE_PICKUP_PATH := "res://addons/adventure_toolkit/templates/objects/Template_Pickup.tscn"
const TEMPLATE_INSPECTABLE_PATH := "res://addons/adventure_toolkit/templates/objects/Template_Inspectable.tscn"
const TEMPLATE_NPC_BASIC_PATH := "res://addons/adventure_toolkit/templates/objects/Template_NPC_Basic.tscn"
const TEMPLATE_PUZZLE_SIMPLE_PATH := "res://addons/adventure_toolkit/templates/objects/Template_Puzzle_Simple.tscn"


func _enter_tree() -> void:
	_ensure_autoload(AUTOLOAD_ATK_SCENES, AUTOLOAD_ATK_SCENES_PATH)
	_ensure_autoload(AUTOLOAD_ATK_STATE, AUTOLOAD_ATK_STATE_PATH)
	_ensure_autoload(AUTOLOAD_ATK_SAVE, AUTOLOAD_ATK_SAVE_PATH)
	_ensure_autoload(AUTOLOAD_ATK_INVENTORY, AUTOLOAD_ATK_INVENTORY_PATH)
	_ensure_autoload(AUTOLOAD_ATK_QUESTS, AUTOLOAD_ATK_QUESTS_PATH)
	_ensure_autoload(AUTOLOAD_ATK_JOURNAL, AUTOLOAD_ATK_JOURNAL_PATH)
	_ensure_autoload(AUTOLOAD_ATK_HINTS, AUTOLOAD_ATK_HINTS_PATH)
	_ensure_autoload(AUTOLOAD_ATK_DIALOGUE, AUTOLOAD_ATK_DIALOGUE_PATH)
	_ensure_autoload(AUTOLOAD_ATK_AUDIO, AUTOLOAD_ATK_AUDIO_PATH)
	_ensure_autoload(AUTOLOAD_ATK_CUTSCENES, AUTOLOAD_ATK_CUTSCENES_PATH)
	_ensure_autoload(AUTOLOAD_ATK_SETTINGS, AUTOLOAD_ATK_SETTINGS_PATH)
	_ensure_autoload(AUTOLOAD_ATK_EPISODES, AUTOLOAD_ATK_EPISODES_PATH)
	_ensure_autoload(AUTOLOAD_ATK_INTERACTION_FEEDBACK, AUTOLOAD_ATK_INTERACTION_FEEDBACK_PATH)
	_ensure_autoload(AUTOLOAD_ATK_WORLD_UI, AUTOLOAD_ATK_WORLD_UI_PATH)
	_ensure_autoload(AUTOLOAD_ATK_INTERACTION_HOVER, AUTOLOAD_ATK_INTERACTION_HOVER_PATH)
	add_tool_menu_item(MENU_ASSIGN_STABLE_IDS, _assign_stable_ids_to_selection)
	add_tool_menu_item(MENU_CREATE_INTERACTION_POINTS, _create_interaction_points_for_selection)
	add_tool_menu_item(MENU_ADD_INSPECT_FALLBACK_RULE, _add_inspect_fallback_rule_to_selection)
	add_tool_menu_item(MENU_VALIDATE_SELECTION, _validate_selected_nodes)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_EXIT, _create_template_exit)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_NPC_TRADE, _create_template_npc_trade)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_TRIGGER, _create_template_trigger)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_DOOR_LOCKED, _create_template_door_locked)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_DOOR_EXIT, _create_template_door_exit)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_PICKUP, _create_template_pickup)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_INSPECTABLE, _create_template_inspectable)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_NPC_BASIC, _create_template_npc_basic)
	add_tool_menu_item(MENU_CREATE_TEMPLATE_PUZZLE_SIMPLE, _create_template_puzzle_simple)


func _exit_tree() -> void:
	_remove_autoload_if_present(AUTOLOAD_ATK_SCENES)
	_remove_autoload_if_present(AUTOLOAD_ATK_STATE)
	_remove_autoload_if_present(AUTOLOAD_ATK_SAVE)
	_remove_autoload_if_present(AUTOLOAD_ATK_INVENTORY)
	_remove_autoload_if_present(AUTOLOAD_ATK_QUESTS)
	_remove_autoload_if_present(AUTOLOAD_ATK_JOURNAL)
	_remove_autoload_if_present(AUTOLOAD_ATK_HINTS)
	_remove_autoload_if_present(AUTOLOAD_ATK_DIALOGUE)
	_remove_autoload_if_present(AUTOLOAD_ATK_AUDIO)
	_remove_autoload_if_present(AUTOLOAD_ATK_CUTSCENES)
	_remove_autoload_if_present(AUTOLOAD_ATK_SETTINGS)
	_remove_autoload_if_present(AUTOLOAD_ATK_EPISODES)
	_remove_autoload_if_present(AUTOLOAD_ATK_INTERACTION_FEEDBACK)
	_remove_autoload_if_present(AUTOLOAD_ATK_WORLD_UI)
	_remove_autoload_if_present(AUTOLOAD_ATK_INTERACTION_HOVER)
	remove_tool_menu_item(MENU_ASSIGN_STABLE_IDS)
	remove_tool_menu_item(MENU_CREATE_INTERACTION_POINTS)
	remove_tool_menu_item(MENU_ADD_INSPECT_FALLBACK_RULE)
	remove_tool_menu_item(MENU_VALIDATE_SELECTION)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_EXIT)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_NPC_TRADE)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_TRIGGER)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_DOOR_LOCKED)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_DOOR_EXIT)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_PICKUP)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_INSPECTABLE)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_NPC_BASIC)
	remove_tool_menu_item(MENU_CREATE_TEMPLATE_PUZZLE_SIMPLE)


func _ensure_autoload(autoload_name: String, autoload_path: String) -> void:
	if ProjectSettings.has_setting("autoload/%s" % autoload_name):
		return

	add_autoload_singleton(autoload_name, autoload_path)


func _remove_autoload_if_present(autoload_name: String) -> void:
	if not ProjectSettings.has_setting("autoload/%s" % autoload_name):
		return

	remove_autoload_singleton(autoload_name)


func _assign_stable_ids_to_selection() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	var nodes := selection.get_selected_nodes()
	if nodes.is_empty():
		push_warning("Adventure Toolkit: no nodes selected.")
		return

	var used_object_ids := _collect_existing_ids("object_id")
	var used_spawn_ids := _collect_existing_ids("spawn_id")
	var used_scene_ids := _collect_existing_ids("scene_id")

	var updated := 0
	for node in nodes:
		if not (node is Node):
			continue
		updated += _assign_missing_id(node, "object_id", "object", used_object_ids)
		updated += _assign_missing_id(node, "spawn_id", "spawn", used_spawn_ids)
		updated += _assign_missing_id(node, "scene_id", "scene", used_scene_ids)

	if updated == 0:
		push_warning("Adventure Toolkit: selection already has stable IDs.")
	else:
		print("Adventure Toolkit: assigned %d stable IDs." % updated)


func _collect_existing_ids(property_name: String) -> Dictionary:
	var out := {}
	var tree := get_tree()
	if tree == null:
		return out
	var root := tree.edited_scene_root
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current := stack.pop_back()
		if current == null:
			continue
		if _node_has_property(current, property_name):
			var value := str(current.get(property_name)).strip_edges()
			if not value.is_empty():
				out[value] = true
		for child in current.get_children():
			if child is Node:
				stack.append(child as Node)
	return out


func _assign_missing_id(node: Node, property_name: String, prefix: String, used: Dictionary) -> int:
	if not _node_has_property(node, property_name):
		return 0
	var current := str(node.get(property_name)).strip_edges()
	if not current.is_empty():
		return 0

	var base := ATKIdTools.build_stable_id(node.name, prefix)
	var candidate := base
	var suffix := 2
	while used.has(candidate):
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	used[candidate] = true

	node.set(property_name, candidate)
	node.notify_property_list_changed()
	return 1


func _node_has_property(node: Object, property_name: String) -> bool:
	for p in node.get_property_list():
		if str(p.get("name", "")) == property_name:
			return true
	return false


func _create_interaction_points_for_selection() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	var nodes := selection.get_selected_nodes()
	if nodes.is_empty():
		push_warning("Adventure Toolkit: no nodes selected.")
		return

	var created := 0
	for node in nodes:
		if not (node is Node3D):
			continue
		var parent := node as Node3D
		var point := _find_existing_interaction_point(parent)
		if point == null:
			point = _spawn_interaction_point(parent)
			if point == null:
				continue
			created += 1

		if _node_has_property(parent, "interaction_point_path"):
			parent.set("interaction_point_path", parent.get_path_to(point))
			parent.notify_property_list_changed()

	if created == 0:
		push_warning("Adventure Toolkit: no new interaction points created.")
	else:
		print("Adventure Toolkit: created %d interaction point node(s)." % created)


func _find_existing_interaction_point(parent: Node3D) -> Node:
	for child in parent.get_children():
		if child.get_script() == null:
			continue
		if child is ATKInteractionPoint:
			return child
	return null


func _spawn_interaction_point(parent: Node3D) -> Node:
	var script := load("res://addons/adventure_toolkit/runtime/interaction/atk_interaction_point.gd")
	if script == null:
		push_error("Adventure Toolkit: could not load ATKInteractionPoint script.")
		return null

	var point := Node3D.new()
	point.name = "InteractionPoint"
	point.set_script(script)
	parent.add_child(point)
	point.owner = get_tree().edited_scene_root
	if point is Node3D:
		(point as Node3D).position = Vector3(0, 0, 0.75)
	return point


func _add_inspect_fallback_rule_to_selection() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	var nodes := selection.get_selected_nodes()
	if nodes.is_empty():
		push_warning("Adventure Toolkit: no nodes selected.")
		return

	var added := 0
	for node in nodes:
		if not (node is ATKAdventureObject):
			continue
		var obj := node as ATKAdventureObject
		if obj.fallback_rule != null:
			continue
		var seq := ATKActionSequence.new()
		seq.sequence_id = "seq_%s_fallback_inspect" % ATKIdTools.build_stable_id(obj.name)
		var step := ATKActionStepInspect.new()
		step.step_id = "step_%s_inspect" % ATKIdTools.build_stable_id(obj.name)
		step.text = obj.inspect_text.strip_edges() if not obj.inspect_text.strip_edges().is_empty() else "%s." % obj.name
		seq.steps = [step]
		var rule := ATKInteractionRule.new()
		rule.rule_id = "rule_%s_fallback" % ATKIdTools.build_stable_id(obj.name)
		rule.is_fallback = true
		rule.actions = seq
		obj.fallback_rule = rule
		obj.notify_property_list_changed()
		added += 1

	if added == 0:
		push_warning("Adventure Toolkit: no fallback rules added.")
	else:
		print("Adventure Toolkit: added %d inspect fallback rule(s)." % added)


func _validate_selected_nodes() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	var nodes := selection.get_selected_nodes()
	if nodes.is_empty():
		push_warning("Adventure Toolkit: no nodes selected.")
		return

	var issue_count := 0
	for node in nodes:
		if node == null or not node.has_method("validate_configuration"):
			continue
		var issues: PackedStringArray = node.call("validate_configuration")
		if issues.is_empty():
			continue
		issue_count += issues.size()
		push_warning("ATK validate: %s -> %s" % [node.name, " | ".join(issues)])

	if issue_count == 0:
		print("Adventure Toolkit: selected nodes passed validation.")


func _create_template_exit() -> void:
	_instantiate_template_into_scene(TEMPLATE_EXIT_PATH)


func _create_template_npc_trade() -> void:
	_instantiate_template_into_scene(TEMPLATE_NPC_TRADE_PATH)


func _create_template_trigger() -> void:
	_instantiate_template_into_scene(TEMPLATE_TRIGGER_PATH)


func _create_template_door_locked() -> void:
	_instantiate_template_into_scene(TEMPLATE_DOOR_LOCKED_PATH)


func _create_template_door_exit() -> void:
	_instantiate_template_into_scene(TEMPLATE_DOOR_EXIT_PATH)


func _create_template_pickup() -> void:
	_instantiate_template_into_scene(TEMPLATE_PICKUP_PATH)


func _create_template_inspectable() -> void:
	_instantiate_template_into_scene(TEMPLATE_INSPECTABLE_PATH)


func _create_template_npc_basic() -> void:
	_instantiate_template_into_scene(TEMPLATE_NPC_BASIC_PATH)


func _create_template_puzzle_simple() -> void:
	_instantiate_template_into_scene(TEMPLATE_PUZZLE_SIMPLE_PATH)


func _instantiate_template_into_scene(template_path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.edited_scene_root
	if root == null:
		push_warning("Adventure Toolkit: open a scene before creating template nodes.")
		return
	var packed := load(template_path) as PackedScene
	if packed == null:
		push_error("Adventure Toolkit: could not load template '%s'." % template_path)
		return
	var instance := packed.instantiate()
	if instance == null:
		push_error("Adventure Toolkit: could not instantiate template '%s'." % template_path)
		return

	var parent := _resolve_template_parent(root)
	parent.add_child(instance)
	instance.owner = root
	if instance is Node3D and parent is Node3D:
		(instance as Node3D).global_transform = (parent as Node3D).global_transform
	_assign_missing_id_recursive(instance, root)
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(instance)
	print("Adventure Toolkit: created template node '%s'." % instance.name)


func _resolve_template_parent(scene_root: Node) -> Node:
	var selection := get_editor_interface().get_selection()
	if selection != null:
		var nodes := selection.get_selected_nodes()
		if not nodes.is_empty() and nodes[0] is Node:
			return nodes[0] as Node
	return scene_root


func _assign_missing_id_recursive(node: Node, scene_root: Node) -> void:
	var used_object_ids := _collect_existing_ids("object_id")
	var used_spawn_ids := _collect_existing_ids("spawn_id")
	var used_scene_ids := _collect_existing_ids("scene_id")
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current := stack.pop_back()
		if current == null:
			continue
		current.owner = scene_root
		_assign_missing_id(current, "object_id", "object", used_object_ids)
		_assign_missing_id(current, "spawn_id", "spawn", used_spawn_ids)
		_assign_missing_id(current, "scene_id", "scene", used_scene_ids)
		for child in current.get_children():
			if child is Node:
				stack.append(child as Node)
