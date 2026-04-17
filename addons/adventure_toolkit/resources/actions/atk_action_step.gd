@tool
class_name ATKActionStep
extends Resource

## Base authored action step (T7.1). Subclasses implement `run`.

@export var step_id := ""
@export_multiline var debug_label := ""


func run(_context: ATKActionContext) -> void:
	ATKLog.warn(
		"Action step '%s' has no runtime implementation." % _debug_name(),
		"ATKAction"
	)


func _debug_name() -> String:
	if not step_id.is_empty():
		return step_id
	if not debug_label.is_empty():
		return debug_label
	return resource_name if not resource_name.is_empty() else "unnamed_step"
