@tool
class_name ATKDialogueNode
extends Resource

@export var node_id := ""
@export var speaker_name := ""
@export_multiline var text := ""
@export var voice_stream: AudioStream
@export var entry_conditions: ATKCondition
@export var fallback_next_node_id := ""
@export var on_enter_actions: ATKActionSequence
@export var on_leave_actions: ATKActionSequence
@export var choices: Array[ATKDialogueChoice] = []
@export var next_node_id := ""
@export var ends_dialogue := false
