@tool
class_name ATKActionSequence
extends Resource

## Ordered list of action steps (T7.2).

@export var sequence_id := ""
@export var steps: Array[ATKActionStep] = []
