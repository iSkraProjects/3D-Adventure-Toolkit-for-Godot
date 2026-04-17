extends Node

## Bus for in-world interaction copy (inspect lines, etc.). UI under [ATKInteractionHud] listens to
## [signal message_shown]. Parent a custom [ATKInteractionHud] (or child scene) under your UI root
## and connect the same signal, or disable [member use_builtin_hud] and wire your own listener.
## [signal message_dismissed] fires when the default HUD hides the panel (Continue, timer, etc.).


signal message_shown(text: String, title: String, object_id: String)
signal message_dismissed


const _DEFAULT_HUD := preload("res://addons/adventure_toolkit/ui/runtime/atk_interaction_hud.tscn")

@export var use_builtin_hud := true


func _ready() -> void:
	if not use_builtin_hud:
		return
	if get_node_or_null("DefaultInteractionHud") != null:
		return
	var hud := _DEFAULT_HUD.instantiate()
	hud.name = "DefaultInteractionHud"
	add_child(hud)


func show_message(text: String, title: String = "", object_id: String = "") -> void:
	var t := text.strip_edges()
	if t.is_empty():
		return
	emit_signal("message_shown", t, title.strip_edges(), object_id.strip_edges())


func is_interaction_message_open() -> bool:
	var hud := get_node_or_null("DefaultInteractionHud")
	if hud != null and hud.has_method("is_feedback_panel_open"):
		return bool(hud.call("is_feedback_panel_open"))
	return false
