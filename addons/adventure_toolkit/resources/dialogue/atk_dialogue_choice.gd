@tool
class_name ATKDialogueChoice
extends Resource

@export var choice_text := ""
@export var target_node_id := ""
@export var conditions: ATKCondition
@export var on_chosen_actions: ATKActionSequence
