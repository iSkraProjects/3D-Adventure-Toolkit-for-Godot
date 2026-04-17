class_name ATKUiInputActions
extends RefCounted

## Helpers so UI can respect **Project Settings → Input Map** while still working out of the box.


## If [param action_name] is missing from [InputMap], creates it. If it exists but has **no**
## events bound, adds [param default_key] once so play works before authors configure keys.
static func ensure_action_with_default_key(action_name: String, default_key: Key) -> void:
	var n := action_name.strip_edges()
	if n.is_empty():
		return
	if not InputMap.has_action(n):
		InputMap.add_action(n)
	if InputMap.action_get_events(n).is_empty():
		var ev := InputEventKey.new()
		ev.physical_keycode = default_key
		InputMap.action_add_event(n, ev)
