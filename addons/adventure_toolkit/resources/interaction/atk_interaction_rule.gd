@tool
class_name ATKInteractionRule
extends Resource

## One rule: optional verb + optional selected item + conditions + actions (T8.1).

@export var rule_id := ""
@export var verb := ""
@export var require_selected_item_id := ""
@export var conditions: ATKCondition
@export var actions: ATKActionSequence
@export var is_fallback := false
