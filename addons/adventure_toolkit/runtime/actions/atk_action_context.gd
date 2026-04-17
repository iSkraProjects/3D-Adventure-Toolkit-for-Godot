class_name ATKActionContext
extends RefCounted

## Runtime payload for action execution (T7.1). Populated by the interaction / action runner.

var actor: Node
var target: Node
var selected_item_id: String = ""
var scene_id: String = ""
var object_id: String = ""
var verb: String = ""


func duplicate_shallow() -> ATKActionContext:
	var c := ATKActionContext.new()
	c.actor = actor
	c.target = target
	c.selected_item_id = selected_item_id
	c.scene_id = scene_id
	c.object_id = object_id
	c.verb = verb
	return c
