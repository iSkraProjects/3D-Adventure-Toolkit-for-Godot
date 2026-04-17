class_name ATKLog
extends RefCounted


static var debug_enabled := true


static func info(message: String, context: String = "ATK") -> void:
	print("[%s] %s" % [context, message])


static func debug(message: String, context: String = "ATK") -> void:
	if not debug_enabled:
		return

	print("[%s][DEBUG] %s" % [context, message])


static func warn(message: String, context: String = "ATK") -> void:
	push_warning("[%s] %s" % [context, message])


static func error(message: String, context: String = "ATK") -> void:
	push_error("[%s] %s" % [context, message])
