@tool
class_name ATKActionStepSay
extends ATKActionStep

@export_multiline var text := ""


func run(context: ATKActionContext) -> void:
	var line := text.strip_edges()
	if line.is_empty():
		ATKLog.warn("Say step '%s' has empty text." % _debug_name(), "ATKAction")
		return
	ATKLog.info(line, "ATKDialogue")
